#!/usr/bin/env bash
# shellcheck shell=bash

INSTALL_PHASES=(
    P00_preflight
    P01_packages
    P02_resolver
    P03_database
    P04_tls
    P05_postfix
    P06_dovecot
    P07_opendkim
    P08_rspamd
    P09_postfixadmin
    P10_roundcube
    P10b_signatures
    P11a_mta_sts
    P11b_autoconfig
    P12_security
    P13_dns
    P15_backup
    P16_report
)

_install_flag_components() {
    local key="$1" val="$2"
    case "$key" in
        --mode) comp_set mode "$val" ;;
        --webmail) comp_set webmail "$val" ;;
        --dashboard) comp_set dashboard "$val" ;;
        --webserver) comp_set webserver "$val" ;;
        --db) comp_set db "$val" ;;
        --spam) comp_set spam "$val" ;;
        --dkim) comp_set dkim "$val" ;;
        --sieve) comp_set sieve "$val" ;;
        --mta-sts) comp_set mta-sts "$val" ;;
        --autoconfig) comp_set autoconfig "$val" ;;
        --signatures) comp_set signatures "$val" ;;
        --sig-policy) comp_set sig-policy "$val" ;;
        --sig-images) comp_set sig-images "$val" ;;
        --resolver) comp_set resolver "$val" ;;
        --local-resolver) if [[ "$val" == "no" ]]; then comp_set resolver system; else comp_set resolver unbound; fi ;;
        --firewall) comp_set firewall "$val" ;;
        --fail2ban) comp_set fail2ban "$val" ;;
        --tls | --cert) comp_set tls "$val" ;;
        --acme-client) comp_set acme-client "$val" ;;
        --acme-challenge) comp_set acme-challenge "$val" ;;
        *) return 1 ;;
    esac
    return 0
}

cmd_install() {
    components_defaults
    local cfgfile="" preset_given=0
    local -a cli=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --preset)
                apply_preset "$2"
                preset_given=1
                shift 2
                ;;
            *)
                cli+=("$1")
                shift
                ;;
        esac
    done
    if ((!preset_given)); then
        apply_preset standard
    fi
    local -a rest=("${cli[@]}")
    local i=0
    while ((i < ${#rest[@]})); do
        local a="${rest[$i]}"
        case "$a" in
            --hostname | --domain | --admin-email | --ip4 | --ip6 | --ssh-port | --admin-allow-ip | --config | --skip | --postscreen | --dane)
                ((i + 1 < ${#rest[@]})) || die "option ${a} requires a value." "$EX_USAGE"
                ;;
        esac
        case "$a" in
            --hostname)
                i=$((i + 1))
                HOSTNAME_ARG="${rest[$i]}"
                ;;
            --domain)
                i=$((i + 1))
                DOMAIN_ARG="${rest[$i]}"
                ;;
            --admin-email)
                i=$((i + 1))
                ADMIN_EMAIL_ARG="${rest[$i]}"
                ;;
            --ip4)
                i=$((i + 1))
                IP4_ARG="${rest[$i]}"
                ;;
            --ip6)
                i=$((i + 1))
                IP6_ARG="${rest[$i]}"
                ;;
            --ssh-port)
                i=$((i + 1))
                SSH_PORT_ARG="${rest[$i]}"
                ;;
            --admin-allow-ip)
                i=$((i + 1))
                ADMIN_ALLOW_IP_ARG="${rest[$i]}"
                ;;
            --config)
                i=$((i + 1))
                cfgfile="${rest[$i]}"
                ;;
            --skip)
                i=$((i + 1))
                SKIP_ARG="${rest[$i]}"
                ;;
            --staging) STAGING=1 ;;
            --postscreen)
                i=$((i + 1))
                POSTSCREEN_ARG="${rest[$i]}"
                ;;
            --dane)
                i=$((i + 1))
                DANE_ARG="${rest[$i]}"
                ;;
            --allow-imap-starttls) ALLOW_IMAP_STARTTLS=1 ;;
            --dry-run) DRY_RUN=1 ;;
            --yes | -y) ASSUME_YES=1 ;;
            *)
                if _install_flag_components "$a" "$([ $((i + 1)) -lt ${#rest[@]} ] && printf '%s' "${rest[$((i + 1))]}")"; then
                    i=$((i + 1))
                else
                    log_warn "unknown option: ${a}"
                fi
                ;;
        esac
        i=$((i + 1))
    done

    if [[ -n "$cfgfile" ]]; then
        [[ -r "$cfgfile" ]] || die "config file not found: ${cfgfile}"
        _install_load_config "$cfgfile"
    fi

    if [[ -n "${SKIP_ARG:-}" ]]; then
        local c
        local -a skips=()
        IFS=',' read -r -a skips <<<"$SKIP_ARG"
        for c in "${skips[@]+"${skips[@]}"}"; do
            case "$c" in
                webmail) comp_set webmail none ;;
                dashboard) comp_set dashboard none ;;
                spam) comp_set spam none ;;
                dkim) comp_set dkim none ;;
                autoconfig) comp_set autoconfig none ;;
                signatures) comp_set signatures none ;;
                *) comp_set "$c" none ;;
            esac
        done
    fi

    MAIL_HOSTNAME="${HOSTNAME_ARG:-mail.${DOMAIN_ARG:-}}"
    PRIMARY_DOMAIN="${DOMAIN_ARG:-${MAIL_HOSTNAME#mail.}}"
    ADMIN_EMAIL="${ADMIN_EMAIL_ARG:-postmaster@${PRIMARY_DOMAIN}}"
    [[ -n "$DOMAIN_ARG" ]] || die "required: --domain example.com" "$EX_USAGE"
    require_domain "$PRIMARY_DOMAIN"
    validate_hostname "$MAIL_HOSTNAME" || die "invalid hostname: ${MAIL_HOSTNAME}"
    require_email "$ADMIN_EMAIL"

    _install_validate_conflicts
    resolve_components

    _install_write_config
    install_run_phases
    _install_summary
}

_install_load_config() {
    local f="$1" line key val
    while IFS= read -r line; do
        [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
        key="${line%%=*}"
        val="${line#*=}"
        case "$key" in
            COMP_*) printf -v "$key" '%s' "$val" ;;
            HOSTNAME) HOSTNAME_ARG="$val" ;;
            DOMAIN) DOMAIN_ARG="$val" ;;
            ADMIN_EMAIL) ADMIN_EMAIL_ARG="$val" ;;
            IP4) IP4_ARG="$val" ;;
            IP6) IP6_ARG="$val" ;;
            SSH_PORT) SSH_PORT_ARG="$val" ;;
        esac
    done <"$f"
}

_install_validate_conflicts() {
    if is_port_listening 25 && ! systemctl is-active --quiet postfix; then
        log_warn "port 25 is in use by another service. Check before continuing."
    fi
}

_install_write_config() {
    config_set MAIL_HOSTNAME "$MAIL_HOSTNAME"
    config_set PRIMARY_DOMAIN "$PRIMARY_DOMAIN"
    config_set ADMIN_EMAIL "$ADMIN_EMAIL"
    config_set MODE "$(comp_get mode)"
    config_set WEBMAIL "$(comp_get webmail)"
    config_set HOSTNAME "$MAIL_HOSTNAME"

    local ip4="${IP4_ARG:-auto}"
    if [[ "$ip4" == "auto" ]]; then ip4="$(detect_public_ip4)"; fi
    [[ -n "$ip4" ]] || log_warn "could not detect the public IP; pass --ip4 explicitly."
    state_set IP4 "$ip4"
    config_set IP4 "$ip4"

    local ip6="${IP6_ARG:-none}"
    if [[ "$ip6" == "none" || -z "$ip6" ]]; then
        INET_PROTOCOLS="ipv4"
        state_set IP6 ""
    else
        INET_PROTOCOLS="all"
        state_set IP6 "$ip6"
        config_set IP6 "$ip6"
    fi
    state_set INET_PROTOCOLS "$INET_PROTOCOLS"
    state_set SSH_PORT "${SSH_PORT_ARG:-22}"
    [[ -n "${ADMIN_ALLOW_IP_ARG:-}" ]] && config_set ADMIN_ALLOW_IP "$ADMIN_ALLOW_IP_ARG"
    config_set ALLOW_IMAP_STARTTLS "${ALLOW_IMAP_STARTTLS:-0}"
    config_set POSTSCREEN "${POSTSCREEN_ARG:-no}"
    state_set DANE "${DANE_ARG:-no}"

    state_set COMP_BACKEND "config"
    components_persist
}

install_run_phases() {
    config_load || true
    local file name id
    for name in "${INSTALL_PHASES[@]}"; do
        file="${APP_ROOT}/phases/${name}.sh"
        id="${name%%_*}"
        [[ -r "$file" ]] || die "phase file not found: ${file}"
        if phase_done "$id"; then
            log_info "[skip] ${id} already complete."
            continue
        fi
        PHASE_REQUIRES=""
        # shellcheck source=/dev/null
        . "$file"
        local req="${PHASE_REQUIRES:-}"
        local reason
        if ! reason="$(phase_requires_check "$req")"; then
            log_info "[skip] ${id} - ${reason}"
            continue
        fi
        header "Running phase ${id} (${name#*_})"
        "phase_${id}" || die "phase ${id} failed." "$EX_ERR"
        phase_mark "$id"
    done
}

_install_summary() {
    if ((DRY_RUN)); then
        :
    else
        require_config || true
    fi
    header "Install summary"
    printf 'Host: %s\nDomain: %s\nAdmin: %s\n' "$MAIL_HOSTNAME" "$PRIMARY_DOMAIN" "$ADMIN_EMAIL"
    printf '\nPasswords (printed once):\n'
    local name
    for name in admin_mailbox db_mailro db_mailpw db_roundcube db_postfixadmin rspamd_ui; do
        local v
        v="$(secret_get "$name" 2>/dev/null || printf '')"
        [[ -n "$v" ]] && printf '  %-16s %s\n' "$name" "$v"
    done
    printf '\nNext steps:\n'
    printf '  1) publish the DNS records:  %s dns-print %s\n' "$APP_CMD" "$PRIMARY_DOMAIN"
    printf '  2) check them:              %s dns-check %s\n' "$APP_CMD" "$PRIMARY_DOMAIN"
    printf '  3) system status:           %s doctor\n' "$APP_CMD"
    cat <<'EOF'

Warm-up (new IP reputation): send 20-50 messages/day per major provider in the first week,
double every 2-3 days if the results are clean, and add the domain to Google Postmaster Tools.
EOF
}
