#!/usr/bin/env bash
# lib/dovecot.sh - Dovecot 2.3 configuration. Refuses Dovecot >= 2.4 until a
# templates/dovecot24/ set is provided (config format changed drastically).
# shellcheck shell=bash

dovecot_version() {
    dovecot --version 2>/dev/null | awk '{print $1}'
}

# dovecot_tpl_dir - select the template set that matches the installed version.
# 2.3.x -> templates/dovecot23 ; 2.4.x -> templates/dovecot24 (must exist).
# If the version cannot be determined (e.g. a dry run before P01 installed
# dovecot) it defaults to the 2.3 set rather than failing.
dovecot_tpl_dir() {
    local v major minor
    v="$(dovecot_version)"
    if [[ -n "$v" ]]; then
        major="${v%%.*}"
        minor="${v#*.}"
        minor="${minor%%.*}"
        if ((major > 2 || (major == 2 && minor >= 4))); then
            printf '%s' "${APP_ROOT}/templates/dovecot24"
            return 0
        fi
    fi
    printf '%s' "${APP_ROOT}/templates/dovecot23"
}

dovecot_version_check() {
    local v dir
    v="$(dovecot_version)"
    dir="$(dovecot_tpl_dir)"
    if [[ ! -d "$dir" ]]; then
        die "Dovecot not supported (no templates in ${dir})." "$EX_VERIFY"
    fi
    if [[ -z "$v" ]]; then
        ((DRY_RUN)) || die "could not determine Dovecot version."
        log_warn "[dry-run] Dovecot version unknown; assuming 2.3."
        return 0
    fi
    log_info "Dovecot ${v} supported (templates: $(basename -- "$dir"))."
}

dovecot_configure() {
    dovecot_version_check
    local conf_d sql_conf db_pw tpl
    conf_d="$(path dovecot_conf_d)"
    sql_conf="$(path dovecot_sql_conf)"
    tpl="$(dovecot_tpl_dir)"
    db_pw="$(secret_ensure db_mailro)"

    TLS_CERT_FILE="${TLS_CERT_FILE:-$(state_get TLS_CERT_FILE 2>/dev/null || path snakeoil_cert)}"
    TLS_KEY_FILE="${TLS_KEY_FILE:-$(state_get TLS_KEY_FILE 2>/dev/null || path snakeoil_key)}"

    ensure_dir "$conf_d" 0755 root:root

    # Plain conf.d files.
    local -a confs=(
        "10-auth.conf"
        "10-mail.conf"
        "10-master.conf"
        "10-ssl.conf"
        "20-lmtp.conf"
        "20-imap.conf"
        "90-quota.conf"
        "90-sieve.conf"
        "zz-mailstead.conf"
    )
    POSTMASTER_DOMAIN="@${PRIMARY_DOMAIN}"
    DOVECOT_SQL_CONF="$sql_conf"
    TPL_VARS="POSTMASTER_DOMAIN DOVECOT_SQL_CONF TLS_CERT_FILE TLS_KEY_FILE"
    local c
    for c in "${confs[@]}"; do
        backup_file "${conf_d}/${c}"
        render_template "${tpl}/${c}.tpl" "${conf_d}/${c}" 0644 root:root
    done

    # auth-sql include and the SQL credentials file.
    backup_file "${conf_d}/auth-sql.conf.ext"
    render_template "${tpl}/auth-sql.conf.ext.tpl" "${conf_d}/auth-sql.conf.ext" 0644 root:root

    DB_MAILRO_PW="$db_pw"
    TPL_VARS="DB_MAILRO_PW"
    backup_file "$sql_conf"
    render_template "${tpl}/dovecot-sql.conf.ext.tpl" "$sql_conf" 0640 root:dovecot

    dovecot_sieve_configure "$tpl"
    dovecot_ensure_logs

    if ((DRY_RUN)); then
        log_info "[dry-run] doveconf -n && restart"
        return 0
    fi
    doveconf -n >/dev/null || die "doveconf -n failed; check ${conf_d}."
    systemctl restart dovecot || die "failed to start dovecot."
}

# dovecot_ensure_logs - create /var/log/dovecot.log (root:dovecot, 0640).
dovecot_ensure_logs() {
    ((DRY_RUN)) && return 0
    touch /var/log/dovecot.log 2>/dev/null || true
    chown root:dovecot /var/log/dovecot.log 2>/dev/null || chown root:root /var/log/dovecot.log 2>/dev/null || true
    chmod 0640 /var/log/dovecot.log 2>/dev/null || true
}

dovecot_sieve_configure() {
    local tpl="${1:-$(dovecot_tpl_dir)}"
    local dir="/etc/dovecot/sieve/before.d"
    ensure_dir "$dir" 0755 root:root
    render_template "${tpl}/sieve/00-spam.sieve.tpl" \
        "${dir}/00-spam.sieve" 0644 root:root
    if ((!DRY_RUN)) && command -v sievec >/dev/null 2>&1; then
        sievec "${dir}/00-spam.sieve" || log_warn "could not compile 00-spam.sieve (will compile on first use)."
    fi
}

dovecot_update_tls_paths() {
    local cert key conf tpl
    cert="$(state_get TLS_CERT_FILE 2>/dev/null || printf '')"
    key="$(state_get TLS_KEY_FILE 2>/dev/null || printf '')"
    [[ -n "$cert" && -n "$key" ]] || return 0
    conf="$(path dovecot_conf_d)/10-ssl.conf"
    tpl="$(dovecot_tpl_dir)"
    if [[ -f "$conf" ]]; then
        TLS_CERT_FILE="$cert"
        TLS_KEY_FILE="$key"
        TPL_VARS="TLS_CERT_FILE TLS_KEY_FILE"
        render_template "${tpl}/10-ssl.conf.tpl" "$conf" 0644 root:root
    fi
    if doveconf -n >/dev/null 2>&1; then systemctl reload dovecot; fi
}
