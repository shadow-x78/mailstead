#!/usr/bin/env bash
# lib/distro/debian.sh - Debian/Ubuntu implementation of the distro interface.

# --- packages ---
pkg_refresh() {
    if ((DRY_RUN)); then
        log_info "[dry-run] apt-get update"
        return 0
    fi
    DEBIAN_FRONTEND=noninteractive apt-get update -qq
}

# pkg_install LOGICAL...
pkg_install() {
    local logical
    local -a reals=()
    for logical in "$@"; do
        if [[ -z "$(pkgmap_get "$logical")" ]]; then
            log_debug "no package for this logical name on Debian: ${logical}"
            continue
        fi
        mapfile -t -O "${#reals[@]}" reals < <(pkgmap_expand "$logical")
    done
    [[ "${#reals[@]}" -gt 0 ]] || {
        log_warn "no packages to install."
        return 0
    }

    local -a uniq=()
    mapfile -t uniq < <(printf '%s\n' "${reals[@]}" | dedupe_lines)

    if ((DRY_RUN)); then
        log_info "[dry-run] apt-get install -y --no-install-recommends ${uniq[*]}"
        return 0
    fi
    if DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        -o Dpkg::Options::=--force-confold -- "${uniq[@]}"; then
        return 0
    fi
    # Retry individually so one missing optional package cannot break the run.
    log_warn "batch install failed; retrying package-by-package (skipping optional ones)."
    local p rc=0
    for p in "${uniq[@]}"; do
        if ! DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            -o Dpkg::Options::=--force-confold -- "$p"; then
            log_warn "could not install: ${p}"
            rc=1
        fi
    done
    return "$rc"
}

# pkg_installed LOGICAL... (or real package names)
pkg_installed() {
    local logical r real
    for logical in "$@"; do
        r="$(pkgmap_get "$logical")"
        [[ -z "$r" ]] && r="$logical"
        while read -r real; do
            [[ -z "$real" ]] && continue
            if ! dpkg-query -W -f='${Status}' "$real" 2>/dev/null | grep -q 'install ok installed'; then
                return 1
            fi
        done < <(printf '%s\n' "$r" | tr ' ' '\n')
    done
    return 0
}

pkg_remove() {
    if ((DRY_RUN)); then
        log_info "[dry-run] apt-get remove -y $*"
        return 0
    fi
    DEBIAN_FRONTEND=noninteractive apt-get remove -y -- "$@"
}

# pkg_real_installed REAL - test a concrete (already-translated) package name.
pkg_real_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

# pkg_enable_repo epel|rspamd|crb ... -> Debian needs none of these.
pkg_enable_repo() (
    _repo="$1"
    log_debug "no extra repositories needed on Debian: ${_repo:-}"
    return 0
)

# --- services ---
_detect_php_fpm_service() {
    if [[ -n "${_PHP_FPM_SVC:-}" ]]; then
        printf '%s' "$_PHP_FPM_SVC"
        return 0
    fi
    local u=""
    u="$(systemctl list-unit-files --type=service 'php*-fpm.service' --no-legend 2>/dev/null |
        awk '{print $1}' | head -n1 || true)"
    if [[ -z "$u" ]]; then
        local f
        for f in /etc/init.d/php*-fpm; do
            [[ -e "$f" ]] || continue
            u="$(basename -- "$f")"
            break
        done
    fi
    _PHP_FPM_SVC="${u:-php-fpm}"
    _PHP_FPM_SVC="${_PHP_FPM_SVC%.service}"
    printf '%s' "$_PHP_FPM_SVC"
}

svc_name() {
    case "$1" in
        kv) printf 'redis-server' ;;
        php-fpm) _detect_php_fpm_service ;;
        mariadb) printf 'mariadb' ;;
        *) printf '%s' "$1" ;;
    esac
}

svc_enable_now() { run systemctl enable --now "$(svc_name "$1")"; }
svc_restart() { run systemctl restart "$(svc_name "$1")"; }
svc_active() { systemctl is-active --quiet "$(svc_name "$1")"; }

web_user() { printf 'www-data'; }

# --- firewall ---
fw_backend() {
    if command -v ufw >/dev/null 2>&1; then
        printf 'ufw'
        return
    fi
    if command -v nft >/dev/null 2>&1; then
        printf 'nftables'
        return
    fi
    printf 'none'
}

fw_open() {
    local port="$1" proto="${2:-tcp}"
    case "$(fw_backend)" in
        ufw)
            if ((DRY_RUN)); then log_info "[dry-run] ufw allow ${port}/${proto}"; else run ufw allow "${port}/${proto}"; fi
            ;;
        nftables) _nft_open "$port" "$proto" ;;
        *) log_warn "no firewall known; skipping opening ${port}/${proto}." ;;
    esac
}

fw_close() {
    local port="$1" proto="${2:-tcp}"
    case "$(fw_backend)" in
        ufw)
            if ((DRY_RUN)); then log_info "[dry-run] ufw deny ${port}/${proto}"; else run ufw deny "${port}/${proto}"; fi
            ;;
        nftables) log_warn "closing via nftables is manual; ${port}/${proto}" ;;
        *) : ;;
    esac
}

_nft_open() {
    local port="$1" proto="${2:-tcp}" rules="${APP_ETC_DIR:-/etc/${APP_SLUG}}/nft.rules"
    if ((DRY_RUN)); then
        log_info "[dry-run] nft open ${port}/${proto}"
        return 0
    fi
    # Append into a managed include file the admin wires into nftables.conf.
    if ! grep -q "dport ${port} accept" "$rules" 2>/dev/null; then
        printf 'tcp dport %s accept\n' "$port" >>"$rules"
    fi
    log_info "added opening ${port}/${proto} to ${rules} (make sure it is included in nftables.conf)."
}

# --- paths ---
path() {
    case "$1" in
        nginx_conf_d) printf '/etc/nginx/conf.d' ;;
        nginx_fastcgi_params) printf '/etc/nginx/fastcgi_params' ;;
        nginx_bin) printf '/usr/sbin/nginx' ;;
        php_fpm_pool_dir)
            local d="" cand
            for cand in /etc/php/*/fpm/pool.d; do
                [[ -d "$cand" ]] || continue
                d="$cand"
                break
            done
            printf '%s' "${d:-/etc/php/8.2/fpm/pool.d}"
            ;;
        php_fpm_socket_dir) printf '/run/php' ;;
        snakeoil_cert) printf '/etc/ssl/certs/ssl-cert-snakeoil.pem' ;;
        snakeoil_key) printf '/etc/ssl/private/ssl-cert-snakeoil.key' ;;
        web_root) printf '/var/www' ;;
        letsencrypt_live) printf '/etc/letsencrypt/live' ;;
        dovecot_conf_d) printf '/etc/dovecot/conf.d' ;;
        dovecot_sql_conf) printf '/etc/dovecot/dovecot-sql.conf.ext' ;;
        postfix_conf) printf '/etc/postfix' ;;
        rspamd_local_d) printf '/etc/rspamd/local.d' ;;
        opendkim_conf) printf '/etc/opendkim' ;;
        fail2ban_jail_d) printf '/etc/fail2ban/jail.d' ;;
        unbound_conf_d) printf '/etc/unbound/unbound.conf.d' ;;
        nginx_root_group) printf 'www-data' ;;
        *) printf '%s' "$1" ;;
    esac
}
