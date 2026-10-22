#!/usr/bin/env bash
# lib/autoconfig.sh - Thunderbird autoconfig + Outlook Autodiscover, MTA-STS,
# TLS-RPT and Apple profiles (plan-3 section E, plan-1 P11).
# shellcheck shell=bash

domains_list_file() { printf '%s/domains.list' "$APP_LIB"; }
autoconfig_ini_file() { printf '%s/autodiscover.ini' "$APP_ETC"; }
autoconfig_web_dir() { printf '%s/web/autoconfig/%s' "$APP_LIB" "$1"; }
mta_sts_web_dir() { printf '%s/web/mta-sts/%s' "$APP_LIB" "$1"; }

domains_list_add() {
    local domain="$1" f
    f="$(domains_list_file)"
    ((DRY_RUN)) && {
        log_info "[dry-run] add ${domain} to domains.list"
        return 0
    }
    ensure_dir "$APP_LIB" 0755 root:root
    touch "$f"
    chmod 0644 "$f"
    grep -qxF "$domain" "$f" || printf '%s\n' "$domain" >>"$f"
    sort -u "$f" -o "$f"
}

domains_list_remove() {
    local domain="$1" f tmp
    f="$(domains_list_file)"
    [[ -f "$f" ]] || return 0
    ((DRY_RUN)) && {
        log_info "[dry-run] remove ${domain} from domains.list"
        return 0
    }
    tmp="$(mktemp)"
    grep -vxF "$domain" "$f" >"$tmp" || true
    mv -f "$tmp" "$f"
}

tls_web_paths() {
    local domain="$1"
    local saved_cert="${TLS_CERT_FILE:-}" saved_key="${TLS_KEY_FILE:-}"
    # Reuse the single cert-path source (tls_set_paths) for the "<domain>-web"
    # certificate; fall back to the mail certificate if it is not issued yet.
    tls_set_paths "${domain}-web"
    WEB_CERT_FULLCHAIN="$TLS_CERT_FILE"
    WEB_CERT_KEY="$TLS_KEY_FILE"
    # tls_set_paths also exports the mail-host vars; restore them.
    TLS_CERT_FILE="$saved_cert"
    TLS_KEY_FILE="$saved_key"
    export TLS_CERT_FILE TLS_KEY_FILE
    if [[ ! -f "$WEB_CERT_FULLCHAIN" ]]; then
        WEB_CERT_FULLCHAIN="$(state_get TLS_CERT_FILE 2>/dev/null || path snakeoil_cert)"
        WEB_CERT_KEY="$(state_get TLS_KEY_FILE 2>/dev/null || path snakeoil_key)"
    fi
    export WEB_CERT_FULLCHAIN WEB_CERT_KEY
}

autoconfig_write_thunderbird() {
    local domain="$1" display="$2" short
    short="${display%%.*}"
    local dst_dir dst
    dst_dir="$(autoconfig_web_dir "$domain")/mail"
    ensure_dir "$dst_dir" 0755 root:root
    dst="${dst_dir}/config-v1.1.xml"
    DOMAIN="$domain"
    DISPLAY_NAME="$(xml_escape "$display")"
    SHORT_NAME="$(xml_escape "$short")"
    TPL_VARS="DOMAIN DISPLAY_NAME SHORT_NAME MAIL_HOSTNAME"
    render_template "${APP_ROOT}/templates/autoconfig/config-v1.1.xml.tpl" "$dst" 0644 root:root
}

autoconfig_write_php() {
    # Ensure PHP-FPM + the autodiscover script and its support files exist.
    local domain="$1"
    APP_ETC_DIR="$APP_ETC"
    APP_LIB_DIR="$APP_LIB"
    nginx_php_pool
    ensure_dir "${APP_OPT}/web" 0755 root:root
    TPL_VARS="APP_ETC APP_LIB"
    render_template "${APP_ROOT}/templates/php/autodiscover.php.tpl" "${APP_OPT}/web/autodiscover.php" 0644 root:root

    local ini
    ini="$(autoconfig_ini_file)"
    if ((!DRY_RUN)); then
        cat >"$ini" <<EOF
; ${APP_MANAGED_MARK}
mail_host=${MAIL_HOSTNAME}
imap_port=993
smtp_port=587
EOF
        chmod 0644 "$ini"
    fi
    ensure_dir "$APP_LIB" 0755 root:root
    local dl
    dl="$(domains_list_file)"
    [[ -f "$dl" ]] || {
        : >"$dl"
        chmod 0644 "$dl"
    }
}

autoconfig_write_nginx() {
    local domain="$1"
    tls_web_paths "$domain"
    DOMAIN="$domain"
    PHP_SOCKET="$(nginx_php_socket)"
    TPL_VARS="DOMAIN APP_LIB APP_OPT PHP_SOCKET WEB_CERT_FULLCHAIN WEB_CERT_KEY"
    render_template "${APP_ROOT}/templates/nginx/autoconfig.conf.tpl" \
        "$(nginx_conf_dir)/${APP_SLUG}-autoconfig-${domain}.conf" 0644 root:root
}

# autoconfig_add_domain DOMAIN [DISPLAY_NAME]
autoconfig_add_domain() {
    local domain="$1" display="${2:-$1}"
    [[ "$(comp_get autoconfig)" != "none" ]] || return 0
    [[ "$(comp_get webserver)" == "none" ]] && return 0

    autoconfig_write_thunderbird "$domain" "$display"
    if [[ "$(comp_get autoconfig)" == "outlook" || "$(comp_get autoconfig)" == "all" ]]; then
        autoconfig_write_php "$domain"
    fi
    ensure_dir "$(autoconfig_web_dir "$domain")/autodiscover" 0755 root:root
    domains_list_add "$domain"

    case "$(comp_get webserver)" in
        nginx)
            autoconfig_write_nginx "$domain"
            ;;
        existing)
            log_info "webserver=existing: created the autoconfig file at $(autoconfig_web_dir "$domain"). Link it manually, then reload."
            ;;
    esac

    # Certificate for the web names (non-fatal on failure).
    if [[ "$(comp_get tls)" == "letsencrypt" ]]; then
        tls_issue_web "$domain" || log_warn "the web certificate for ${domain} has not been issued yet."
    fi
    if [[ "$(comp_get webserver)" == "nginx" ]]; then nginx_reload_safe; fi
}

autoconfig_del_domain() {
    local domain="$1"
    domains_list_remove "$domain"
    nginx_remove_vhost "autoconfig-${domain}"
    local d
    d="$(autoconfig_web_dir "$domain")"
    if [[ -d "$d" ]]; then
        backup_file "$d"
        ((DRY_RUN)) || rm -rf -- "$d"
    fi
    if [[ "$(comp_get webserver)" == "nginx" ]]; then nginx_reload_safe; fi
}

# ---- MTA-STS ----
mta_sts_write_policy() {
    local domain="$1" mode="${2:-testing}" max_age="${3:-86400}"
    local dir
    dir="$(mta_sts_web_dir "$domain")/.well-known"
    ensure_dir "$dir" 0755 root:root
    if ((DRY_RUN)); then
        log_info "[dry-run] write mta-sts policy for ${domain}"
        return 0
    fi
    cat >"${dir}/mta-sts.txt" <<EOF
version: STSv1
mode: ${mode}
mx: ${MAIL_HOSTNAME}
max_age: ${max_age}
EOF
    chmod 0644 "${dir}/mta-sts.txt"
}

mta_sts_write_nginx() {
    local domain="$1"
    tls_web_paths "$domain"
    DOMAIN="$domain"
    TPL_VARS="DOMAIN APP_LIB WEB_CERT_FULLCHAIN WEB_CERT_KEY"
    render_template "${APP_ROOT}/templates/nginx/mta-sts.conf.tpl" \
        "$(nginx_conf_dir)/${APP_SLUG}-mta-sts-${domain}.conf" 0644 root:root
}

mta_sts_add_domain() {
    local domain="$1"
    [[ "$(comp_get mta-sts)" == "yes" ]] || return 0
    [[ "$(comp_get webserver)" == "nginx" ]] || return 0
    mta_sts_write_policy "$domain" testing 86400
    mta_sts_write_nginx "$domain"
    state_set "MTA_STS_ID_${domain}" "$(date +%Y%m%d%H%M%S)"
    nginx_reload_safe
}

cmd_mta_sts_enforce() {
    require_config
    local domain="${1:-}"
    [[ -n "$domain" ]] || die "usage: ${APP_CMD} mta-sts-enforce DOMAIN" "$EX_USAGE"
    require_domain "$domain"
    mta_sts_write_policy "$domain" enforce 604800
    state_set "MTA_STS_ID_${domain}" "$(date +%Y%m%d%H%M%S)"
    nginx_reload_safe
    log_info "MTA-STS raised to enforce. Update the _mta-sts DNS record with a new id."
}

# ---- CLI ----
cmd_autoconfig() {
    require_config
    local sub="${1:-regenerate}"
    shift || true
    case "$sub" in
        regenerate)
            local target="" all=0
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --all)
                        all=1
                        shift
                        ;;
                    *)
                        target="$1"
                        shift
                        ;;
                esac
            done
            if ((all)); then
                local d
                while read -r d; do
                    [[ -n "$d" ]] && autoconfig_add_domain "$d"
                done < <(db_list_domains)
            else
                [[ -n "$target" ]] || die "usage: ${APP_CMD} autoconfig regenerate [DOMAIN|--all]" "$EX_USAGE"
                require_domain "$target"
                autoconfig_add_domain "$target"
            fi
            log_info "autoconfig settings regenerated."
            ;;
        *) die "unknown subcommand: ${sub}" "$EX_USAGE" ;;
    esac
}

cmd_test_autoconfig() {
    require_config
    local email="${1:-}"
    require_email "$email"
    local domain="${email#*@}"
    local host
    host="$MAIL_HOSTNAME"
    local fail=0

    header "autoconfig check for ${email}"

    if curl -fsS "https://autoconfig.${domain}/mail/config-v1.1.xml" 2>/dev/null |
        xmllint --noout - 2>/dev/null; then
        printf '  ✔ Thunderbird XML file is valid\n'
    else
        printf '  ✘ Thunderbird XML file is missing or invalid\n'
        fail=1
    fi

    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' "http://autoconfig.${domain}/mail/config-v1.1.xml" 2>/dev/null || printf 000)"
    if [[ "$code" == "200" ]]; then printf '  ✔ HTTP autoconfig = 200\n'; else
        printf '  ✘ HTTP autoconfig = %s\n' "$code"
        fail=1
    fi

    code="$(curl -s -o /dev/null -w '%{http_code}' "http://autodiscover.${domain}/autodiscover/autodiscover.xml" 2>/dev/null || printf 000)"
    if [[ "$code" == "302" ]]; then printf '  ✔ HTTP autodiscover = 302\n'; else
        printf '  ✘ HTTP autodiscover = %s (expected 302)\n' "$code"
        fail=1
    fi

    local req out
    req="<?xml version=\"1.0\"?><Autodiscover xmlns=\"http://schemas.microsoft.com/exchange/autodiscover/outlook/requestschema/2006\"><Request><EMailAddress>${email}</EMailAddress><AcceptableResponseSchema>http://schemas.microsoft.com/exchange/autodiscover/outlook/responseschema/2006a</AcceptableResponseSchema></Request></Autodiscover>"
    out="$(curl -fsS -X POST -H 'Content-Type: text/xml' --data "$req" \
        "https://autodiscover.${domain}/autodiscover/autodiscover.xml" 2>/dev/null || printf '')"
    if [[ "$out" == *"<Server>${host}</Server>"* && "$out" == *"<LoginName>${email}</LoginName>"* ]]; then
        printf '  ✔ Autodiscover response includes the server and address\n'
    else
        printf '  ✘ Autodiscover response is incomplete\n'
        fail=1
    fi

    code="$(curl -s -o /dev/null -w '%{http_code}' -X POST --data "$req" \
        "https://autodiscover.${domain}/autodiscover/autodiscover.xml" 2>/dev/null || printf 000)"
    # Expect 404 for a non-hosted address; test with a bogus domain.
    local badreq badcode
    badreq="${req//${domain}/not-hosted.invalid}"
    badcode="$(curl -s -o /dev/null -w '%{http_code}' -X POST --data "$badreq" \
        "https://autodiscover.${domain}/autodiscover/autodiscover.xml" 2>/dev/null || printf 000)"
    if [[ "$badcode" == "404" ]]; then printf '  ✔ non-hosted domain => 404\n'; else
        printf '  ✘ non-hosted domain => %s (expected 404)\n' "$badcode"
        fail=1
    fi

    local srv
    srv="$(dig +short SRV "_autodiscover._tcp.${domain}" 2>/dev/null | tr '\n' ' ')"
    if [[ -n "$srv" ]]; then printf '  ✔ SRV _autodiscover: %s\n' "$srv"; else printf '  ✘ SRV _autodiscover missing\n'; fi

    if ((fail)); then
        log_warn "see docs/autoconfig.md. The mandatory test: desktop Outlook on Windows."
        return "$EX_ERR"
    fi
    log_info "all autoconfig/autodiscover checks passed."
}

cmd_apple_profile() {
    require_config
    local email="${1:-}"
    require_email "$email"
    local domain="${email#*@}"
    local out="${APP_ETC}/profiles"
    ensure_dir "$out" 0755 root:root
    local dst="${out}/${email}.mobileconfig"
    DISPLAY_NAME="$(xml_escape "$domain")"
    EMAIL="$email"
    PAYLOAD_ID="com.${APP_SLUG}.${email}"
    PAYLOAD_UUID="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || gen_hex 32)"
    TPL_VARS="DISPLAY_NAME EMAIL MAIL_HOSTNAME PAYLOAD_ID PAYLOAD_UUID"
    render_template "${APP_ROOT}/templates/autoconfig/mobileconfig.tpl" "$dst" 0644 root:root
    log_info "created the Apple file: ${dst} (does not contain the password)."
}
