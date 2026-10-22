#!/usr/bin/env bash
# shellcheck shell=bash

: "${STAGING:=0}"

tls_set_paths() {
    local host="$1" base
    base="/etc/ssl/${APP_SLUG}/${host}"
    case "$(comp_get tls)" in
        letsencrypt)
            if [[ "$(comp_get acme-client)" == "acme.sh" ]]; then
                TLS_CERT_FILE="${base}/fullchain.pem"
                TLS_KEY_FILE="${base}/privkey.pem"
            else
                TLS_CERT_FILE="$(path letsencrypt_live)/${host}/fullchain.pem"
                TLS_KEY_FILE="$(path letsencrypt_live)/${host}/privkey.pem"
            fi
            ;;
        selfsigned)
            TLS_CERT_FILE="${base}/selfsigned.crt"
            TLS_KEY_FILE="${base}/selfsigned.key"
            ;;
        existing)
            TLS_CERT_FILE="${EXISTING_CERT:-/etc/ssl/certs/ssl-cert-snakeoil.pem}"
            TLS_KEY_FILE="${EXISTING_KEY:-/etc/ssl/private/ssl-cert-snakeoil.key}"
            ;;
        *)
            TLS_CERT_FILE="/etc/ssl/certs/ssl-cert-snakeoil.pem"
            TLS_KEY_FILE="/etc/ssl/private/ssl-cert-snakeoil.key"
            ;;
    esac
    export TLS_CERT_FILE TLS_KEY_FILE
}

tls_bootstrap_paths() {
    TLS_CERT_FILE="$(path snakeoil_cert)"
    TLS_KEY_FILE="$(path snakeoil_key)"
    export TLS_CERT_FILE TLS_KEY_FILE
}

tls_ensure_vars() {
    if [[ -z "${TLS_CERT_FILE:-}" ]]; then
        TLS_CERT_FILE="$(state_get TLS_CERT_FILE 2>/dev/null || path snakeoil_cert)"
    fi
    if [[ -z "${TLS_KEY_FILE:-}" ]]; then
        TLS_KEY_FILE="$(state_get TLS_KEY_FILE 2>/dev/null || path snakeoil_key)"
    fi
    export TLS_CERT_FILE TLS_KEY_FILE
}

tls_ensure_selfsigned() (
    local host="$1"
    shift
    local base="/etc/ssl/${APP_SLUG}/${host}"
    local crt="${base}/selfsigned.crt" key="${base}/selfsigned.key"
    [[ -f "$crt" && -f "$key" ]] && return 0
    ((DRY_RUN)) && {
        log_info "[dry-run] self-signed cert for ${host}"
        return 0
    }
    ensure_dir "$base" 0755 root:root
    local san="DNS:${host}"
    local n
    for n in "$@"; do san+=",DNS:${n}"; done
    openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
        -keyout "$key" -out "$crt" \
        -subj "/CN=${host}" -addext "subjectAltName=${san}" >/dev/null 2>&1
    chmod 0640 "$crt" "$key"
    log_info "created a self-signed certificate for ${host}."
)

_certbot() {
    local -a args=(certbot)
    ((STAGING)) && args+=(--staging)
    args+=("$@")
    if ((DRY_RUN)); then
        log_info "[dry-run] ${args[*]}"
        return 0
    fi
    "${args[@]}"
}

tls_issue_le_host() {
    local host="$1"
    shift
    local -a dargs=(-d "$host")
    local n
    for n in "$@"; do dargs+=(-d "$n"); done

    if [[ "$(comp_get acme-client)" == "acme.sh" ]]; then
        _tls_issue_acmesh "$host" "$host" "$@"
        return
    fi

    case "$(comp_get acme-challenge)" in
        standalone)
            _certbot certonly --standalone --preferred-challenges http \
                --cert-name "$host" "${dargs[@]}" \
                -m "${ADMIN_EMAIL}" --agree-tos --no-eff-email --non-interactive \
                --key-type rsa --rsa-key-size 2048
            ;;
        dns-cloudflare)
            _certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
                --cert-name "$host" "${dargs[@]}" \
                -m "${ADMIN_EMAIL}" --agree-tos --no-eff-email --non-interactive \
                --key-type rsa --rsa-key-size 2048
            ;;
        *)
            ensure_dir /var/www/letsencrypt 0755 root:root
            _certbot certonly --webroot -w /var/www/letsencrypt \
                --cert-name "$host" "${dargs[@]}" \
                -m "${ADMIN_EMAIL}" --agree-tos --no-eff-email --non-interactive \
                --key-type rsa --rsa-key-size 2048
            ;;
    esac
}

tls_issue_web() {
    local domain="$1"
    local -a names=("autoconfig.${domain}" "autodiscover.${domain}")
    if [[ "$(comp_get mta-sts)" == "yes" ]]; then
        names+=("mta-sts.${domain}")
    fi

    local n
    local -a dargs=()
    for n in "${names[@]}"; do
        local ip
        ip="$(dig +short "$n" A 2>/dev/null | tail -n1)"
        if [[ -z "$ip" ]]; then
            log_warn "no A/CNAME record for ${n}. Issue the certificate later with: ${APP_CMD} cert-issue --web ${domain}"
            return 1
        fi
        dargs+=(-d "$n")
    done

    if [[ "$(comp_get acme-client)" == "acme.sh" ]]; then
        _tls_issue_acmesh "${domain}-web" "${names[0]}" "${names[@]:1}"
        return $?
    fi

    ensure_dir /var/www/letsencrypt 0755 root:root
    _certbot certonly --webroot -w /var/www/letsencrypt \
        --cert-name "${domain}-web" "${dargs[@]}" \
        -m "${ADMIN_EMAIL}" --agree-tos --no-eff-email --non-interactive \
        --key-type rsa --rsa-key-size 2048
}

_tls_issue_acmesh() {
    local certname="$1" primary="$2"
    shift 2
    local acme="/root/.acme.sh/acme.sh"
    local base="/etc/ssl/${APP_SLUG}/${certname}"
    ensure_dir "$base" 0755 root:root
    local -a dargs=(-d "$primary")
    local n
    for n in "$@"; do dargs+=(-d "$n"); done
    if ((DRY_RUN)); then
        log_info "[dry-run] acme.sh issue ${certname}"
        return 0
    fi
    "$acme" --issue "${dargs[@]}" --keylength 2048 \
        --cert-file "$base/cert.pem" --key-file "$base/privkey.pem" \
        --fullchain-file "$base/fullchain.pem" ||
        return 1
}

tls_install_deploy_hook() {
    local hook="/etc/letsencrypt/renewal-hooks/deploy/${APP_SLUG}.sh"
    ensure_dir "$(dirname -- "$hook")" 0755 root:root
    if ((DRY_RUN)); then
        log_info "[dry-run] write deploy hook"
        return 0
    fi
    cat >"$hook" <<EOF
#!/bin/sh
/usr/sbin/postfix check && /usr/sbin/postfix reload
/usr/bin/doveconf -n >/dev/null 2>&1 && systemctl reload dovecot
if [ -x "$(path nginx_bin)" ]; then $(path nginx_bin) -t 2>/dev/null && systemctl reload nginx; fi
exit 0
EOF
    chmod 0755 "$hook"
}

tls_configure() {
    local host="${MAIL_HOSTNAME}"
    local -a san=()
    if [[ "$(comp_get dashboard)" != "none" ]]; then
        san+=("admin.${PRIMARY_DOMAIN}")
    fi

    tls_set_paths "$host"
    local mode
    mode="$(comp_get tls)"

    case "$mode" in
        selfsigned)
            tls_ensure_selfsigned "$host" "${san[@]}"
            state_set CERT_MODE selfsigned
            ;;
        existing)
            [[ -f "${TLS_CERT_FILE:-}" && -f "${TLS_KEY_FILE:-}" ]] ||
                die "existing certificate not found: ${TLS_CERT_FILE:-?}"
            state_set CERT_MODE existing
            ;;
        letsencrypt)
            if [[ "$(comp_get acme-client)" == "acme.sh" ]]; then
                if ! command -v "${ACME_SH:-}" >/dev/null 2>&1 && [[ ! -x /root/.acme.sh/acme.sh ]]; then
                    log_warn "acme.sh is not installed; it will be installed when needed. Use certbot to avoid that."
                fi
            fi
            if tls_issue_le_host "$host" "${san[@]}"; then
                state_set CERT_MODE real
            else
                log_warn "failed to issue a Let's Encrypt certificate; the snakeoil placeholder is used until DNS is fixed."
                tls_bootstrap_paths
                state_set CERT_MODE bootstrap
            fi
            ;;
    esac

    tls_set_paths "$host"
    tls_install_deploy_hook
    state_set TLS_CERT_FILE "$TLS_CERT_FILE"
    state_set TLS_KEY_FILE "$TLS_KEY_FILE"
}

tls_reload_services() {
    if [[ "$(comp_get mailbox)" == "yes" ]] && svc_exists dovecot; then
        svc_reload_safe dovecot doveconf -n
    fi
    if svc_exists postfix; then
        if postfix check >/dev/null 2>&1; then systemctl reload postfix || true; fi
    fi
}

cmd_cert_issue() {
    local web=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --web)
                web="${2:-}"
                shift 2
                ;;
            --staging)
                STAGING=1
                shift
                ;;
            *) die "unknown option for cert-issue: $1" "$EX_USAGE" ;;
        esac
    done
    require_config
    if [[ -n "$web" ]]; then
        require_domain "$web"
        if tls_issue_web "$web"; then log_info "issued the web certificate for ${web}."; else die "failed to issue the web certificate for ${web}"; fi
    else
        tls_configure
    fi
    tls_reload_services
}

cmd_cert_renew() {
    require_config
    if ((DRY_RUN)); then
        log_info "[dry-run] certbot renew"
        return 0
    fi
    if command -v certbot >/dev/null 2>&1; then
        certbot renew --quiet || log_warn "certbot renew finished with a warning."
    else
        /root/.acme.sh/acme.sh --cron --home /root/.acme.sh || log_warn "acme.sh --cron finished with a warning."
    fi
    log_info "certificates renewed (certbot.timer or the acme.sh cron handles scheduling)."
}

cmd_cert_status() {
    require_config
    local host="$MAIL_HOSTNAME"
    local crt
    tls_set_paths "$host"
    crt="${TLS_CERT_FILE:-}"
    if [[ ! -r "$crt" ]]; then
        log_warn "no readable certificate at ${crt}"
        return "$EX_ERR"
    fi
    header "Certificate status (${host})"
    openssl x509 -in "$crt" -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null || true
    local end epoch now days
    end="$(openssl x509 -in "$crt" -noout -enddate 2>/dev/null | cut -d= -f2)"
    epoch="$(date -d "$end" +%s 2>/dev/null || printf 0)"
    now="$(date +%s)"
    days=$(((epoch - now) / 86400))
    if ((days < 14)); then
        log_warn "the certificate expires in ${days} days."
    else
        log_info "days until the certificate expires: ${days}."
    fi
    if command -v certbot >/dev/null 2>&1; then
        printf 'certbot.timer: %s\n' "$(systemctl is-enabled certbot.timer 2>/dev/null || printf 'not enabled')"
    fi
}
