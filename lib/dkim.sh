#!/usr/bin/env bash
# lib/dkim.sh - OpenDKIM signing keys and tables (one key per domain).
# shellcheck shell=bash

opendkim_conf_dir() { path opendkim_conf; }

dkim_configure() {
    local dir
    dir="$(opendkim_conf_dir)"
    ensure_dir "$dir" 0755 root:root
    OPENDKIM_CONF="$dir"
    TPL_VARS="OPENDKIM_CONF"
    backup_file "${dir}/opendkim.conf"
    render_template "${APP_ROOT}/templates/opendkim/opendkim.conf.tpl" "${dir}/opendkim.conf" 0644 root:root

    # trusted hosts
    if ((!DRY_RUN)); then
        cat >"${dir}/trusted.hosts" <<EOF
127.0.0.1
::1
localhost
${MAIL_HOSTNAME}
EOF
        chmod 0644 "${dir}/trusted.hosts"
        touch "${dir}/key.table" "${dir}/signing.table"
        chmod 0644 "${dir}/key.table" "${dir}/signing.table"
    fi

    dkim_fix_defaults
    if ((DRY_RUN)); then
        log_info "[dry-run] restart opendkim"
        return 0
    fi
    systemctl restart opendkim || die "failed to start opendkim."
    wait_for_port 127.0.0.1 8891 10 || log_warn "opendkim is not listening on 8891 yet."
}

# Debian ships /etc/default/opendkim with SOCKET/RUNDIR that can override the conf.
dkim_fix_defaults() {
    local f="/etc/default/opendkim"
    [[ -f "$f" ]] || return 0
    if grep -qE '^[[:space:]]*SOCKET=' "$f"; then
        backup_file "$f"
        if ((DRY_RUN)); then
            log_info "[dry-run] comment SOCKET= in ${f}"
            return 0
        fi
        awk '{ if ($0 ~ /^[[:space:]]*SOCKET=/) print "#" $0; else print }' "$f" >"${f}.tmp" && mv -f "${f}.tmp" "$f"
    fi
}

_dkim_selector_default() {
    date +mail%Y%m
}

dkim_key_dir() { printf '%s/keys/%s' "$(opendkim_conf_dir)" "$1"; }

# dkim_add_domain DOMAIN [SELECTOR]
dkim_add_domain() {
    local domain="$1" sel="${2:-$(_dkim_selector_default)}"
    require_domain "$domain"
    local dir keytable signtable
    dir="$(dkim_key_dir "$domain")"
    keytable="$(opendkim_conf_dir)/key.table"
    signtable="$(opendkim_conf_dir)/signing.table"

    if [[ ! -f "${dir}/${sel}.private" ]]; then
        if ((DRY_RUN)); then
            log_info "[dry-run] opendkim-genkey ${domain} ${sel}"
            return 0
        fi
        install -d -o opendkim -g opendkim -m 0750 "$dir"
        opendkim-genkey -b 2048 -h rsa-sha256 -d "$domain" -s "$sel" -D "$dir" ||
            die "failed to generate DKIM key for ${domain}"
        chown opendkim:opendkim "${dir}/${sel}.private"
        chmod 0600 "${dir}/${sel}.private"
        chmod 0644 "${dir}/${sel}.txt"
    fi

    if ((DRY_RUN)); then
        log_info "[dry-run] update DKIM tables for ${domain}"
        return 0
    fi
    _dkim_table_upsert "$keytable" "$domain" "${sel}._domainkey.${domain} ${domain}:${sel}:${dir}/${sel}.private"
    _dkim_table_upsert "$signtable" "$domain" "*@${domain} ${sel}._domainkey.${domain}"
    systemctl reload opendkim || systemctl restart opendkim
    state_set "DKIM_SELECTOR_${domain}" "$sel"
}

# Remove every table line that refers to DOMAIN (as a whole DNS token, so
# sub.example.com is never treated as example.com), then append the new line.
_dkim_table_remove_domain() {
    local table="$1" domain="$2"
    [[ -f "$table" ]] || return 0
    local tmp
    tmp="$(mktemp)"
    grep -vE "(^|[^A-Za-z0-9.-])${domain}([^A-Za-z0-9.-]|\$)" "$table" >"$tmp" 2>/dev/null || true
    mv -f "$tmp" "$table"
}

_dkim_table_upsert() {
    local table="$1" domain="$2" newline="$3"
    [[ -f "$table" ]] || : >"$table"
    _dkim_table_remove_domain "$table" "$domain"
    printf '%s\n' "$newline" >>"$table"
    sort -u -o "$table" "$table"
}

dkim_remove_domain() {
    local domain="$1" sel
    sel="$(state_get "DKIM_SELECTOR_${domain}" 2>/dev/null || printf '')"
    if ((DRY_RUN)); then
        log_info "[dry-run] remove DKIM for ${domain}"
        return 0
    fi
    _dkim_table_remove_domain "$(opendkim_conf_dir)/key.table" "$domain"
    _dkim_table_remove_domain "$(opendkim_conf_dir)/signing.table" "$domain"
    if [[ -n "$sel" ]]; then rm -rf -- "$(dkim_key_dir "$domain")"; fi
    systemctl reload opendkim 2>/dev/null || true
}

dkim_selector() {
    local domain="$1"
    state_get "DKIM_SELECTOR_${domain}" 2>/dev/null || _dkim_selector_default
}

# dkim_record_string DOMAIN [SEL] -> single-line TXT value.
dkim_record_string() {
    local domain="$1" sel="${2:-$(dkim_selector "$1")}"
    local txt
    txt="$(dkim_key_dir "$domain")/${sel}.txt"
    [[ -r "$txt" ]] || return 1
    local parts
    parts="$(grep -o '"[^"]*"' "$txt" | tr -d '"' | tr -d '\n')"
    printf '%s' "$parts"
}

dkim_rotate() {
    local domain="$1"
    require_domain "$domain"
    local old new
    old="$(dkim_selector "$domain")"
    new="mail$(date +%Y%m%d%H%M)"
    dkim_add_domain "$domain" "$new"
    header "New DKIM record (selector: ${new})"
    dkim_print_txt "$domain" "$new"
    log_warn "publish the new record, then verify with dns-check. Keep the old selector (${old}) in DNS for at least 7 days."
    state_set "DKIM_SELECTOR_${domain}" "$new"
}

dkim_print_txt() {
    local domain="$1" sel="${2:-$(dkim_selector "$1")}"
    local rec
    rec="$(dkim_record_string "$domain" "$sel")" || {
        log_warn "no DKIM record for ${domain}"
        return 1
    }
    printf '%s._domainkey.%s. TXT "%s"\n' "$sel" "$domain" "$rec"
    # Split (BIND) form for panels that cap label length at 255.
    printf '%s._domainkey.%s. TXT (\n' "$sel" "$domain"
    printf '%s' "$rec" | fold -w 255 | awk '{printf "  \"%s\"\n", $0}'
    printf ')\n'
}

cmd_dkim_show() {
    require_config
    local domain="${1:-}"
    [[ -n "$domain" ]] || die "usage: ${APP_CMD} dkim-show DOMAIN" "$EX_USAGE"
    require_domain "$domain"
    dkim_print_txt "$domain"
}

cmd_dkim_rotate() {
    require_config
    local domain="${1:-}"
    [[ -n "$domain" ]] || die "usage: ${APP_CMD} dkim-rotate DOMAIN" "$EX_USAGE"
    dkim_rotate "$domain"
}
