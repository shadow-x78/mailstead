#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Postfix MTA Configuration
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

# shellcheck shell=bash

postfix_sql_dir() { printf '%s/sql' "$(path postfix_conf)"; }

postfix_compat_vars() {
    local v major minor
    v="$(postconf -h mail_version 2>/dev/null | awk '{print $1}' || true)"
    [[ -n "$v" ]] || v="0"
    major="${v%%.*}"
    minor="${v#*.}"
    minor="${minor%%.*}"
    if ((major > 3 || (major == 3 && minor >= 6))); then
        POSTFIX_COMPAT_LEVEL="3.6"
        POSTFIX_TLS_PROTOCOLS=">=TLSv1.2"
    else
        POSTFIX_COMPAT_LEVEL="2"
        POSTFIX_TLS_PROTOCOLS="TLSv1.2, TLSv1.3"
    fi
    export POSTFIX_COMPAT_LEVEL POSTFIX_TLS_PROTOCOLS
}

postfix_write_sql_maps() {
    local dir db_pw
    dir="$(postfix_sql_dir)"
    db_pw="$(secret_ensure db_mailro)"
    ensure_dir "$dir" 0750 root:postfix
    DB_MAILRO_PW="$db_pw"
    TPL_VARS="DB_MAILRO_PW"
    local pair
    for pair in \
        "virtual_domains:mysql_virtual_domains_maps.cf" \
        "virtual_mailbox:mysql_virtual_mailbox_maps.cf" \
        "virtual_alias:mysql_virtual_alias_maps.cf" \
        "virtual_alias_catchall:mysql_virtual_alias_catchall_maps.cf" \
        "sender_login:mysql_sender_login_maps.cf"; do
        local tpl="${pair%%:*}" out="${pair##*:}"
        render_template "${APP_ROOT}/templates/postfix/sql/${tpl}.cf.tpl" \
            "${dir}/${out}" 0640 root:postfix
    done
}

postfix_maps_block() {
    if [[ "$(comp_get mailbox)" != "yes" ]]; then
        printf '# mailbox=no: virtual maps and SASL disabled\n'
        return
    fi
    local dir
    dir="$(postfix_sql_dir)"
    cat <<EOF
virtual_mailbox_domains = mysql:${dir}/mysql_virtual_domains_maps.cf
virtual_mailbox_maps = mysql:${dir}/mysql_virtual_mailbox_maps.cf
virtual_alias_maps = mysql:${dir}/mysql_virtual_alias_maps.cf
virtual_transport = lmtp:unix:private/dovecot-lmtp
smtpd_sender_login_maps = mysql:${dir}/mysql_sender_login_maps.cf
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = no
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = \$myhostname
broken_sasl_auth_clients = no
EOF
}

postfix_milters_block() {
    if [[ "$(comp_get spam)" == "rspamd" ]]; then
        printf 'smtpd_milters = inet:127.0.0.1:11332\n'
    else
        printf '# rspamd disabled: no inbound milter\n'
    fi
    if [[ "$(comp_get dkim)" == "opendkim" ]]; then
        printf 'non_smtpd_milters = inet:127.0.0.1:8891\n'
    else
        printf '# opendkim disabled: no signing milter\n'
    fi
}

postfix_configure() {
    TLS_CERT_FILE="${TLS_CERT_FILE:-$(state_get TLS_CERT_FILE 2>/dev/null || path snakeoil_cert)}"
    TLS_KEY_FILE="${TLS_KEY_FILE:-$(state_get TLS_KEY_FILE 2>/dev/null || path snakeoil_key)}"
    if [[ "$(comp_get mailbox)" == "yes" ]]; then
        postfix_write_sql_maps
    fi

    POSTFIX_MAPS_BLOCK="$(postfix_maps_block)"
    POSTFIX_MILTERS_BLOCK="$(postfix_milters_block)"
    postfix_compat_vars
    INET_PROTOCOLS="${INET_PROTOCOLS:-ipv4}"
    SMTP_TLS_LEVEL="${SMTP_TLS_LEVEL:-may}"
    TPL_VARS="MAIL_HOSTNAME PRIMARY_DOMAIN INET_PROTOCOLS SMTP_TLS_LEVEL TLS_CERT_FILE TLS_KEY_FILE POSTFIX_MAPS_BLOCK POSTFIX_MILTERS_BLOCK POSTFIX_COMPAT_LEVEL POSTFIX_TLS_PROTOCOLS"

    local lines="${APP_ETC}/generated/main.cf.lines"
    render_template "${APP_ROOT}/templates/postfix/main.cf.tpl" "$lines" 0640 root:root
    backup_file "$(path postfix_conf)/main.cf"
    if ((DRY_RUN)); then
        log_info "[dry-run] postconf_apply_file ${lines}"
    else
        postconf_apply_file "$lines"
    fi

    postfix_master_configure
    postfix_write_transport
    postfix_aliases
    postfix_ensure_logs

    if ((DRY_RUN)); then
        log_info "[dry-run] postfix check && reload"
        return 0
    fi
    postfix check || die "postfix check failed after applying config."
    systemctl reload postfix 2>/dev/null || systemctl restart postfix
}

postfix_ensure_logs() {
    ((DRY_RUN)) && return 0
    local log
    log="$(path mail_log)"
    touch "$log" 2>/dev/null || true
    chown postfix:adm "$log" 2>/dev/null || chown postfix:postfix "$log" 2>/dev/null || true
    chmod 0640 "$log" 2>/dev/null || true
}

postfix_master_configure() {
    if ((DRY_RUN)); then
        log_info "[dry-run] postconf -M/-P master.cf"
        return 0
    fi
    postconf -M 'slow/unix=slow unix - - n - 5 smtp' >/dev/null
    postconf -M 'postlog/unix-dgram=postlog unix-dgram n - n - 1 postlogd' >/dev/null

    if [[ "$(comp_get mailbox)" == "yes" ]]; then
        postconf -M 'submission/inet=submission inet n - y - - smtpd' >/dev/null
        postconf -P 'submission/inet/syslog_name=postfix/submission' >/dev/null
        postconf -P 'submission/inet/smtpd_tls_security_level=encrypt' >/dev/null
        postconf -P 'submission/inet/smtpd_sasl_auth_enable=yes' >/dev/null
        postconf -P 'submission/inet/smtpd_tls_auth_only=yes' >/dev/null
        postconf -P 'submission/inet/smtpd_reject_unlisted_recipient=no' >/dev/null
        postconf -P 'submission/inet/smtpd_client_restrictions=permit_sasl_authenticated,reject' >/dev/null
        postconf -P 'submission/inet/smtpd_relay_restrictions=permit_sasl_authenticated,reject' >/dev/null
        postconf -P 'submission/inet/smtpd_sender_restrictions=reject_sender_login_mismatch,permit_sasl_authenticated,reject' >/dev/null
        postconf -P 'submission/inet/milter_macro_daemon_name=ORIGINATING' >/dev/null
        if [[ "$(comp_get dkim)" == "opendkim" ]]; then
            postconf -P 'submission/inet/smtpd_milters=inet:127.0.0.1:8891' >/dev/null
        fi

        postconf -M 'smtps/inet=smtps inet n - y - - smtpd' >/dev/null
        postconf -P 'smtps/inet/syslog_name=postfix/smtps' >/dev/null
        postconf -P 'smtps/inet/smtpd_tls_wrappermode=yes' >/dev/null
        postconf -P 'smtps/inet/smtpd_tls_security_level=encrypt' >/dev/null
        postconf -P 'smtps/inet/smtpd_sasl_auth_enable=yes' >/dev/null
        postconf -P 'smtps/inet/smtpd_reject_unlisted_recipient=no' >/dev/null
        postconf -P 'smtps/inet/smtpd_client_restrictions=permit_sasl_authenticated,reject' >/dev/null
        postconf -P 'smtps/inet/smtpd_relay_restrictions=permit_sasl_authenticated,reject' >/dev/null
        postconf -P 'smtps/inet/smtpd_sender_restrictions=reject_sender_login_mismatch,permit_sasl_authenticated,reject' >/dev/null
        postconf -P 'smtps/inet/milter_macro_daemon_name=ORIGINATING' >/dev/null
    else
        postconf -X 'submission/inet' >/dev/null 2>&1 || true
        postconf -X 'smtps/inet' >/dev/null 2>&1 || true
    fi
}

postfix_write_transport() {
    local f
    f="$(path postfix_conf)/transport"
    render_template "${APP_ROOT}/templates/postfix/transport.tpl" "$f" 0644 root:root
    if ((!DRY_RUN)); then
        postmap "$f" || die "postmap failed on transport"
    fi
}

postfix_aliases() {
    local f="/etc/aliases"
    if ((DRY_RUN)); then
        log_info "[dry-run] update /etc/aliases"
        return 0
    fi
    backup_file "$f"
    touch "$f"
    grep -qE '^postmaster:' "$f" || printf 'postmaster: root\n' >>"$f"
    if ! grep -qE '^root:' "$f"; then
        printf 'root: %s\n' "${ADMIN_EMAIL}" >>"$f"
    fi
    newaliases 2>/dev/null || true
}

postfix_update_tls_paths() {
    local cert key
    cert="$(state_get TLS_CERT_FILE 2>/dev/null || printf '')"
    key="$(state_get TLS_KEY_FILE 2>/dev/null || printf '')"
    [[ -n "$cert" && -n "$key" ]] || return 0
    run postconf -e "smtpd_tls_cert_file = ${cert}"
    run postconf -e "smtpd_tls_key_file = ${key}"
    if postfix check >/dev/null 2>&1; then systemctl reload postfix; fi
}

postfix_footer_enable() {
    local libexec="$APP_LIBEXEC"
    if ((DRY_RUN)); then
        log_info "[dry-run] enable footer transport"
        return 0
    fi
    postconf -M 'footer/unix=footer unix - n n - 10 pipe' >/dev/null
    postconf -P "footer/unix/flags=Rq user=${APP_SLUG}-filter argv=${libexec}/mailstead-footer.py \${sender} \${recipient}" >/dev/null
    postconf -M 'reinject/inet=127.0.0.1:10025 inet n - n - - smtpd' >/dev/null
    postconf -P 'reinject/inet/syslog_name=postfix/reinject' >/dev/null
    postconf -P 'reinject/inet/content_filter=' >/dev/null
    postconf -P 'reinject/inet/smtpd_milters=inet:127.0.0.1:8891' >/dev/null
    postconf -P 'reinject/inet/milter_macro_daemon_name=ORIGINATING' >/dev/null
    postconf -P 'reinject/inet/smtpd_client_restrictions=permit_mynetworks,reject' >/dev/null
    postconf -P 'reinject/inet/smtpd_relay_restrictions=permit_mynetworks,reject' >/dev/null
    postconf -P 'reinject/inet/smtpd_recipient_restrictions=permit_mynetworks,reject' >/dev/null
    postconf -P 'reinject/inet/mynetworks=127.0.0.0/8' >/dev/null
    postconf -P 'submission/inet/content_filter=footer:dummy' >/dev/null
    if postfix check >/dev/null 2>&1; then systemctl reload postfix; fi
}

postfix_footer_disable() {
    if ((DRY_RUN)); then
        log_info "[dry-run] disable footer transport"
        return 0
    fi
    postconf -P 'submission/inet/content_filter=' >/dev/null 2>&1 || true
    postconf -X 'footer/unix' >/dev/null 2>&1 || true
    postconf -X 'reinject/inet' >/dev/null 2>&1 || true
    if postfix check >/dev/null 2>&1; then systemctl reload postfix; fi
}
