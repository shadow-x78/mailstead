#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Package Installation Phase
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

PHASE_REQUIRES=""

_p01_logicals() {
    printf '%s\n' postfix
    [[ "$(comp_get mailbox)" == "yes" ]] && printf '%s\n' dovecot
    [[ "$(comp_get dkim)" == "opendkim" ]] && printf '%s\n' opendkim
    [[ "$(comp_get spam)" == "rspamd" ]] && printf '%s\n' rspamd kv
    [[ "$(comp_get db)" == "mariadb" ]] && printf '%s\n' mariadb
    [[ "$(comp_get webserver)" == "nginx" ]] && printf '%s\n' nginx
    if [[ "$(comp_get webserver)" == "nginx" || "$(comp_get webmail)" != "none" || "$(comp_get dashboard)" != "none" || "$(comp_get signatures)" != "none" ]]; then
        printf '%s\n' php-fpm
    fi
    [[ "$(comp_get tls)" == "letsencrypt" && "$(comp_get acme-client)" == "certbot" ]] && printf '%s\n' certbot
    [[ "$(comp_get fail2ban)" == "yes" ]] && printf '%s\n' fail2ban
    [[ "$(comp_get resolver)" == "unbound" ]] && printf '%s\n' unbound
    [[ "$(comp_get signatures)" != "none" ]] && printf '%s\n' python3
    [[ "$(comp_get autoconfig)" != "none" ]] && printf '%s\n' xmllint
    printf '%s\n' openssl curl dig ca-certificates logrotate
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        printf '%s\n' ssl-cert unattended-upgrades pflogsumm
    else
        printf '%s\n' policycoreutils unattended-upgrades pflogsumm
    fi
}

phase_P01() {
    header "P01 packages"

    pkg_refresh

    if [[ "$DISTRO_FAMILY" == "rhel" ]]; then
        pkg_enable_repo epel
        pkg_enable_repo crb
        pkg_enable_repo rspamd
    fi

    if [[ "$DISTRO_FAMILY" == "debian" ]] && ((!DRY_RUN)); then
        printf 'postfix postfix/main_mailer_type select Internet Site\n' | debconf-set-selections
        printf 'postfix postfix/mailname string %s\n' "$MAIL_HOSTNAME" | debconf-set-selections
    fi

    local -a logicals=()
    mapfile -t logicals < <(_p01_logicals)

    local -a reals=() preinstalled=()
    if ((!DRY_RUN)); then
        mapfile -t reals < <(pkgmap_expand "${logicals[@]}" | sort -u)
        local r
        for r in "${reals[@]}"; do
            pkg_real_installed "$r" && preinstalled+=("$r")
        done
    fi

    pkg_install "${logicals[@]}"

    ensure_vmail_user

    if [[ "$DISTRO_FAMILY" == "rhel" ]] && declare -F mta_set_default >/dev/null 2>&1; then
        mta_set_default
    fi

    [[ "$(comp_get db)" == "mariadb" ]] && svc_enable_now mariadb
    [[ "$(comp_get webserver)" == "nginx" ]] && svc_enable_now nginx
    if [[ "$(comp_get webserver)" == "nginx" || "$(comp_get webmail)" != "none" ]]; then
        svc_enable_now php-fpm
    fi
    [[ "$(comp_get resolver)" == "unbound" ]] && svc_enable_now unbound

    _p01_record_installed "${reals[@]+"${reals[@]}"}" -- "${preinstalled[@]+"${preinstalled[@]}"}"
    log_info "package installation complete."
}

_p01_record_installed() {
    ((DRY_RUN)) && return 0
    local -a reals=() pre=()
    local seen_sep=0 x
    for x in "$@"; do
        if [[ "$x" == "--" ]]; then
            seen_sep=1
            continue
        fi
        if ((seen_sep)); then pre+=("$x"); else reals+=("$x"); fi
    done
    local -a newly=() p skip
    for x in "${reals[@]+"${reals[@]}"}"; do
        skip=0
        for p in "${pre[@]+"${pre[@]}"}"; do
            [[ "$p" == "$x" ]] && {
                skip=1
                break
            }
        done
        ((skip)) || newly+=("$x")
    done
    state_set INSTALLED_PKGS "$(printf '%s ' "${newly[@]+"${newly[@]}"}")"
}
