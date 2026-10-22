#!/usr/bin/env bash
# lib/report.sh - status, queue, logs, doctor, delivery tests (P16).
# shellcheck shell=bash

_core_services() {
    printf '%s\n' postfix
    [[ "$(comp_get mailbox)" == "yes" ]] && printf '%s\n' dovecot
    [[ "$(comp_get dkim)" == "opendkim" ]] && printf '%s\n' opendkim
    [[ "$(comp_get spam)" == "rspamd" ]] && printf '%s\n' rspamd
    [[ "$(comp_get db)" == "mariadb" ]] && printf '%s\n' "$(svc_name mariadb)"
    [[ "$(comp_get spam)" == "rspamd" ]] && printf '%s\n' "$(svc_name kv)"
    [[ "$(comp_get webserver)" == "nginx" ]] && printf '%s\n' nginx
    [[ "$(comp_get fail2ban)" == "yes" ]] && printf '%s\n' fail2ban
}

cmd_status() {
    require_config
    header "${APP_NAME} - system status (${MAIL_HOSTNAME})"
    local s
    printf '%-14s %s\n' "SERVICE" "STATE"
    while read -r s; do
        [[ -z "$s" ]] && continue
        printf '%-14s %s\n' "$s" "$(systemctl is-active "$s" 2>/dev/null || printf unknown)"
    done < <(_core_services)

    local q
    q="$(postqueue -j 2>/dev/null | wc -l || printf 0)"
    printf '\nQueue: %s messages\n' "$q"

    if command -v openssl >/dev/null 2>&1; then
        local cert
        cert="$(state_get TLS_CERT_FILE 2>/dev/null || printf '')"
        if [[ -n "$cert" && -r "$cert" ]]; then
            local end
            end="$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)"
            printf 'certificate expiry: %s\n' "$end"
        fi
    fi

    printf '\nDisk:\n'
    df -h / /var/vmail 2>/dev/null | sed -n '1,3p' || true
    if [[ -d /var/vmail ]]; then
        printf '\nSize of /var/vmail: %s\n' "$(du -sh /var/vmail 2>/dev/null | awk '{print $1}')"
    fi

    printf '\nLast 5 error lines from mail.log:\n'
    grep -iE 'error|fatal|reject' /var/log/mail.log 2>/dev/null | tail -n 5 || printf '  (none)\n'
}

cmd_queue() {
    require_config
    local sub="${1:-list}"
    case "$sub" in
        list) postqueue -p ;;
        flush) run postqueue -f ;;
        delete-all)
            confirm "delete all messages in the queue permanently?" || die "cancelled."
            run postsuper -d ALL
            ;;
        *) die "usage: ${APP_CMD} queue list|flush|delete-all --yes" "$EX_USAGE" ;;
    esac
}

cmd_logs() {
    require_config
    local which="postfix" nlines="100" follow=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            postfix | dovecot | rspamd | nginx)
                which="$1"
                shift
                ;;
            -n)
                nlines="${2:-100}"
                shift 2
                ;;
            -f)
                follow=1
                shift
                ;;
            *) shift ;;
        esac
    done
    local file
    case "$which" in
        postfix) file="/var/log/mail.log" ;;
        dovecot) file="/var/log/dovecot.log" ;;
        rspamd) file="/var/log/rspamd/rspamd.log" ;;
        nginx) file="/var/log/nginx/error.log" ;;
    esac
    [[ -r "$file" ]] || die "log file not found: ${file}"
    if ((follow)); then tail -n "$nlines" -f "$file"; else tail -n "$nlines" "$file"; fi
}

cmd_test_send() {
    require_config
    local from="" to="" via="submission" pw=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from)
                from="${2:-}"
                shift 2
                ;;
            --to)
                to="${2:-}"
                shift 2
                ;;
            --via)
                via="${2:-}"
                shift 2
                ;;
            --password)
                pw="${2:-}"
                shift 2
                ;;
            *) die "unknown option: $1" "$EX_USAGE" ;;
        esac
    done
    [[ -n "$from" && -n "$to" ]] || die "usage: ${APP_CMD} test-send --from a@d --to x@y" "$EX_USAGE"
    require_email "$from"
    require_email "$to"
    if [[ "$via" == "local" ]]; then
        run swaks --to "$to" --from "$from" --server 127.0.0.1 --port 25
    else
        # The tool does not store mailbox passwords; use --password or the admin box.
        if [[ -z "$pw" ]]; then
            pw="$(secret_get admin_mailbox 2>/dev/null || printf '')"
        fi
        [[ -n "$pw" ]] || die "pass --password for the ${from} password." "$EX_USAGE"
        # run_secret: keep the password out of the log.
        run_secret swaks --to "$to" --from "$from" --server "$MAIL_HOSTNAME" --port 587 \
            --tls --auth LOGIN --auth-user "$from" --auth-password "$pw"
    fi
    log_info "In Gmail/iCloud, verify SPF/DKIM/DMARC = PASS via 'Show original'."
}

cmd_doctor() {
    require_config
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --redact)
                REDACT=1
                shift
                ;;
            *) shift ;;
        esac
    done
    header "${APP_NAME} doctor"
    local issues=0
    local s
    while read -r s; do
        [[ -z "$s" ]] && continue
        if systemctl is-active --quiet "$s"; then
            printf '  ✔ %s running\n' "$s"
        else
            printf '  ✘ %s stopped\n' "$s"
            issues=$((issues + 1))
        fi
    done < <(_core_services)

    local cert days
    cert="$(state_get TLS_CERT_FILE 2>/dev/null || printf '')"
    if [[ -n "$cert" && -r "$cert" ]]; then
        days="$(_cert_days_left "$cert")"
        if ((days < 14)); then
            printf '  ✘ the certificate expires in %s days\n' "$days"
            issues=$((issues + 1))
        else printf '  ✔ the certificate is valid for %s days\n' "$days"; fi
    else
        printf '  ✘ no readable certificate\n'
        issues=$((issues + 1))
    fi

    local q
    q="$(postqueue -j 2>/dev/null | wc -l || printf 0)"
    if ((q > 100)); then
        printf '  ✘ the queue is large (%s)\n' "$q"
        issues=$((issues + 1))
    else printf '  ✔ queue %s\n' "$q"; fi

    local ptr
    ptr="$(dig +short -x "$(dns_domain_ip4)" 2>/dev/null | tr -d '.' | tr '\n' ' ')"
    if [[ "$ptr" == *"$MAIL_HOSTNAME"* ]]; then printf '  ✔ PTR ok\n'; else
        printf '  ✘ PTR does not match %s\n' "$(redact_value "$MAIL_HOSTNAME")"
        issues=$((issues + 1))
    fi

    if [[ "$(comp_get signatures)" != "none" ]]; then
        if command -v python3 >/dev/null 2>&1; then printf '  ✔ python3 present\n'; else
            printf '  ✘ python3 is missing (required for signatures)\n'
            issues=$((issues + 1))
        fi
    fi

    # Reputation / DNSBL check (via the configured resolver).
    local pub_ip
    pub_ip="$(dns_domain_ip4)"
    if command -v dig >/dev/null 2>&1 && [[ -n "$pub_ip" ]]; then
        doctor_dnsbl "$pub_ip"
    fi

    if [[ "$(comp_get autoconfig)" != "none" ]]; then
        printf '  i autoconfig: run %s test-autoconfig user@%s for a full check\n' "$APP_CMD" "$PRIMARY_DOMAIN"
    fi

    if command -v ausearch >/dev/null 2>&1; then
        local avc
        avc="$(ausearch -m avc -ts recent 2>/dev/null | tail -n 3 || true)"
        [[ -n "$avc" ]] && printf '  ✘ recent SELinux AVC denials (see ausearch)\n'
    fi

    printf '\n'
    if ((issues == 0)); then
        log_info "all checks are green."
        return 0
    fi
    log_warn "number of warnings: ${issues}"
    return 1
}

_cert_days_left() {
    local crt="$1" end epoch now
    end="$(openssl x509 -in "$crt" -noout -enddate 2>/dev/null | cut -d= -f2)"
    epoch="$(date -d "$end" +%s 2>/dev/null || printf 0)"
    now="$(date +%s)"
    printf '%s' "$(((epoch - now) / 86400))"
}

report_redact_enabled() { [[ "${REDACT:-0}" == "1" ]]; }

# redact_value TEXT - with --redact, mask IPv4/IPv6 addresses before printing.
redact_value() {
    local v="$1"
    if report_redact_enabled; then
        v="$(printf '%s' "$v" | awk '{gsub(/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/, "x.x.x.x"); print}')"
    fi
    printf '%s' "$v"
}

# DNSBL check via local resolver only (Spamhaus blocks public resolvers).
doctor_dnsbl() {
    local ip="${1:-$(dns_domain_ip4)}"
    [[ -n "$ip" ]] || return 0
    local rev
    rev="$(printf '%s' "$ip" | awk -F. '{print $4"."$3"."$2"."$1}')"
    local res
    res="$(dig +short "${rev}.zen.spamhaus.org" 2>/dev/null | head -n1)"
    case "$res" in
        127.0.0.1* | 127.0.0.2* | 127.0.0.3*) log_warn "IP is listed in Spamhaus: ${res}" ;;
        127.255.255.*) log_warn "DNSBL query refused (disallowed source); use the local unbound." ;;
        "") log_info "IP is not listed in Spamhaus." ;;
        *) log_warn "unexpected DNSBL response: ${res}" ;;
    esac
}
