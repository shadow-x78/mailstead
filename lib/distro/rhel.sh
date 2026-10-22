#!/usr/bin/env bash
# lib/distro/rhel.sh - Fedora / RHEL-family (AlmaLinux, Rocky, RHEL) interface.

# --- packages ---
pkg_refresh() {
    if ((DRY_RUN)); then
        log_info "[dry-run] dnf makecache"
        return 0
    fi
    dnf -q makecache
}

# pkg_install LOGICAL...
pkg_install() {
    local logical
    local -a reals=()
    for logical in "$@"; do
        if [[ -z "$(pkgmap_get "$logical")" ]]; then
            log_debug "no package for this logical name on RHEL-family: ${logical}"
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
        log_info "[dry-run] dnf install -y ${uniq[*]}"
        return 0
    fi
    local -a opts=(--setopt=install_weak_deps=False)
    if dnf install -y "${opts[@]}" -- "${uniq[@]}"; then
        return 0
    fi
    log_warn "batch install failed; retrying package-by-package (skipping optional ones)."
    local p rc=0
    for p in "${uniq[@]}"; do
        if ! dnf install -y "${opts[@]}" -- "$p"; then
            log_warn "could not install: ${p} (it may be optional or outside the repositories)"
            rc=1
        fi
    done
    return "$rc"
}

pkg_installed() {
    local logical r real
    for logical in "$@"; do
        r="$(pkgmap_get "$logical")"
        [[ -z "$r" ]] && r="$logical"
        while read -r real; do
            [[ -z "$real" ]] && continue
            rpm -q "$real" >/dev/null 2>&1 || return 1
        done < <(printf '%s\n' "$r" | tr ' ' '\n')
    done
    return 0
}

pkg_remove() {
    if ((DRY_RUN)); then
        log_info "[dry-run] dnf remove -y $*"
        return 0
    fi
    dnf remove -y -- "$@"
}

# pkg_real_installed REAL - test a concrete (already-translated) package name.
pkg_real_installed() {
    rpm -q "$1" >/dev/null 2>&1
}

# pkg_enable_repo epel|crb|rspamd
pkg_enable_repo() {
    local repo="$1"
    case "$repo" in
        epel)
            if rpm -q epel-release >/dev/null 2>&1; then return 0; fi
            run dnf install -y epel-release || log_warn "could not install epel-release."
            ;;
        crb)
            # RHEL/Alma/Rocky: enable the CodeReady/CRB repo for dovecot-pigeonhole etc.
            if ((DRY_RUN)); then
                log_info "[dry-run] enable crb"
                return 0
            fi
            dnf config-manager --set-enabled crb 2>/dev/null ||
                dnf config-manager --set-enabled codeready-builder-for-rhel-"${DISTRO_VERSION_ID%%.*}"-x86_64-rpms 2>/dev/null ||
                log_warn "could not enable the CRB repository (it may already be enabled)."
            ;;
        rspamd)
            if ! rpm -q rspamd >/dev/null 2>&1 && ! dnf -q list --available rspamd >/dev/null 2>&1; then
                log_warn "rspamd is not available from the repositories; install it from the official rspamd repo, then retry."
            fi
            ;;
        *)
            log_debug "unknown repository: ${repo}"
            ;;
    esac
}

# --- services ---
_detect_kv_service() {
    if systemctl list-unit-files --type=service --no-legend 2>/dev/null | grep -q '^valkey\.service'; then
        printf 'valkey'
    else
        printf 'redis'
    fi
}

svc_name() {
    case "$1" in
        kv) _detect_kv_service ;;
        php-fpm) printf 'php-fpm' ;;
        mariadb) printf 'mariadb' ;;
        *) printf '%s' "$1" ;;
    esac
}

svc_enable_now() { run systemctl enable --now "$(svc_name "$1")"; }
svc_restart() { run systemctl restart "$(svc_name "$1")"; }
svc_active() { systemctl is-active --quiet "$(svc_name "$1")"; }

web_user() { printf 'nginx'; }

# --- default MTA alternatives (sendmail/exim -> postfix) ---
mta_set_default() {
    if ((DRY_RUN)); then
        log_info "[dry-run] set default mta to postfix"
        return 0
    fi
    local unit
    for unit in sendmail.service exim.service; do
        if systemctl list-unit-files --type=service --no-legend 2>/dev/null | grep -q "^${unit}"; then
            systemctl disable --now "$unit" 2>/dev/null || true
        fi
    done
    if command -v alternatives >/dev/null 2>&1 && [[ -x /usr/sbin/sendmail.postfix ]]; then
        alternatives --set mta /usr/sbin/sendmail.postfix 2>/dev/null || true
    fi
}

# --- firewall ---
fw_backend() {
    if command -v firewall-cmd >/dev/null 2>&1; then
        printf 'firewalld'
    else printf 'none'; fi
}

fw_open() {
    local port="$1" proto="${2:-tcp}"
    if ((DRY_RUN)); then
        log_info "[dry-run] firewalld open ${port}/${proto}"
        return 0
    fi
    if ! systemctl is-active --quiet firewalld; then
        log_warn "firewalld is not enabled; ${port}/${proto} was not opened."
        return 0
    fi
    firewall-cmd --permanent --add-port="${port}/${proto}" >/dev/null
    firewall-cmd --reload >/dev/null
}

fw_close() {
    local port="$1" proto="${2:-tcp}"
    if ((DRY_RUN)); then
        log_info "[dry-run] firewalld close ${port}/${proto}"
        return 0
    fi
    systemctl is-active --quiet firewalld || return 0
    firewall-cmd --permanent --remove-port="${port}/${proto}" >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null
}

# --- paths ---
path() {
    case "$1" in
        nginx_conf_d) printf '/etc/nginx/conf.d' ;;
        nginx_fastcgi_params) printf '/etc/nginx/fastcgi_params' ;;
        nginx_bin) printf '/usr/sbin/nginx' ;;
        php_fpm_pool_dir) printf '/etc/php-fpm.d' ;;
        php_fpm_socket_dir) printf '/run/php-fpm' ;;
        snakeoil_cert) printf '/etc/pki/tls/certs/localhost.crt' ;;
        snakeoil_key) printf '/etc/pki/tls/private/localhost.key' ;;
        web_root) printf '/var/www' ;;
        letsencrypt_live) printf '/etc/letsencrypt/live' ;;
        dovecot_conf_d) printf '/etc/dovecot/conf.d' ;;
        dovecot_sql_conf) printf '/etc/dovecot/dovecot-sql.conf.ext' ;;
        postfix_conf) printf '/etc/postfix' ;;
        rspamd_local_d) printf '/etc/rspamd/local.d' ;;
        opendkim_conf) printf '/etc/opendkim' ;;
        fail2ban_jail_d) printf '/etc/fail2ban/jail.d' ;;
        unbound_conf_d) printf '/etc/unbound/conf.d' ;;
        nginx_root_group) printf 'nginx' ;;
        *) printf '%s' "$1" ;;
    esac
}
