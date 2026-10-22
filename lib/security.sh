#!/usr/bin/env bash
# lib/security.sh - firewall, fail2ban and SELinux hardening (P12).
# shellcheck shell=bash

security_configure() {
    firewall_configure
    if [[ "$(comp_get fail2ban)" == "yes" ]]; then
        fail2ban_configure
    fi
    selinux_apply
    logrotate_configure
}

# Never enable a firewall that was not already running without confirmation.
# Never close SSH.
firewall_configure() {
    local choice backend ssh_port
    choice="$(comp_get firewall)"
    backend="$(fw_backend)"
    ssh_port="$(state_get SSH_PORT 2>/dev/null || printf '22')"

    if [[ "$choice" == "none" ]]; then
        log_info "firewall disabled at the user's request."
        return 0
    fi
    if [[ "$backend" == "none" ]]; then
        log_warn "no firewall known on this system; skipping port opening."
        return 0
    fi

    case "$backend" in
        ufw)
            if ! systemctl is-active --quiet ufw && [[ "$(ufw status 2>/dev/null | head -n1)" != *active* ]]; then
                confirm "ufw is not enabled. Enable it now (SSH will not be locked out)?" ||
                    {
                        log_warn "ufw was not enabled."
                        return 0
                    }
                run ufw default deny incoming
                run ufw default allow outgoing
            fi
            run ufw allow "${ssh_port}/tcp"
            ;;
        firewalld)
            if ! systemctl is-active --quiet firewalld; then
                log_warn "firewalld is not enabled; it will not be enabled automatically (it may drop connections). Open the ports manually:"
                _print_ports "$ssh_port"
                return 0
            fi
            ;;
    esac

    local p
    for p in 25 80 443 465 587 993; do
        fw_open "$p" tcp
    done
    if [[ "${ALLOW_IMAP_STARTTLS:-0}" == "1" ]]; then
        fw_open 143 tcp
    fi
    log_info "opened the required ports (SSH ${ssh_port} and IMAP/SMTP/HTTPS). 4190/3306/6379/11334 were not opened."
}

_print_ports() {
    printf '  firewall-cmd --permanent --add-port=%s/tcp\n' "$@"
    printf '  firewall-cmd --permanent --add-port={25,80,443,465,587,993}/tcp\n'
    printf '  firewall-cmd --reload\n'
}

fail2ban_configure() {
    local dir rc_logs
    dir="$(path fail2ban_jail_d)"
    ensure_dir "$dir" 0755 root:root
    rc_logs="$(roundcube_logs_dir 2>/dev/null || printf '%s/roundcube/logs' "$(path web_root)")"

    local ignore="ignoreip = 127.0.0.1/8 ::1"
    [[ -n "${ADMIN_IP:-}" ]] && ignore+=" ${ADMIN_IP}"
    FAIL2BAN_IGNORE="$ignore"
    ROUNDCUBE_LOGS="$rc_logs"
    TPL_VARS="FAIL2BAN_IGNORE ROUNDCUBE_LOGS"
    render_template "${APP_ROOT}/templates/fail2ban/jail.local.tpl" "${dir}/${APP_SLUG}.local" 0644 root:root

    if ((DRY_RUN)); then
        log_info "[dry-run] restart fail2ban"
        return 0
    fi
    systemctl enable --now fail2ban >/dev/null 2>&1 || true
    systemctl restart fail2ban || log_warn "failed to start fail2ban; check the filters."
    if fail2ban-client status >/dev/null 2>&1; then log_info "fail2ban is running."; else log_warn "fail2ban is not responding."; fi
}

selinux_apply() {
    command -v getenforce >/dev/null 2>&1 || return 0
    local mode
    mode="$(getenforce 2>/dev/null || printf 'Disabled')"
    [[ "$mode" == "Enforcing" ]] || {
        log_info "SELinux: ${mode} (no changes)."
        return 0
    }

    log_info "SELinux is active (Enforcing): applying booleans and file contexts."
    run setsebool -P httpd_can_network_connect 1
    run setsebool -P httpd_can_network_connect_db 1

    local -a fctx=(
        "/var/www/roundcube/(temp|logs)(/.*)?|httpd_sys_rw_content_t"
        "/var/lib/${APP_SLUG}/signatures/rendered(/.*)?|httpd_sys_content_t"
        "/var/lib/${APP_SLUG}/signatures/assets(/.*)?|httpd_sys_content_t"
        "/var/lib/${APP_SLUG}/web(/.*)?|httpd_sys_content_t"
    )
    local entry path ctx
    for entry in "${fctx[@]}"; do
        path="${entry%%|*}"
        ctx="${entry##*|}"
        run semanage fcontext -a -t "$ctx" "$path" 2>/dev/null || true
    done
    run restorecon -Rv /var/www/roundcube 2>/dev/null || true
    run restorecon -Rv "/var/lib/${APP_SLUG}" 2>/dev/null || true

    # vmail + DKIM + certs must be reachable by the mail daemons.
    run semanage fcontext -a -t mail_home_rw_t "/var/vmail(/.*)?" 2>/dev/null || true
    run restorecon -Rv /var/vmail 2>/dev/null || true

    if command -v ausearch >/dev/null 2>&1; then
        local avc
        avc="$(ausearch -m avc -ts recent 2>/dev/null | tail -n 20 || true)"
        [[ -n "$avc" ]] && log_warn "recent AVC denials present; review: ausearch -m avc -ts recent"
    fi
}

logrotate_configure() {
    local f="/etc/logrotate.d/${APP_SLUG}"
    if ((DRY_RUN)); then
        log_info "[dry-run] logrotate ${f}"
        return 0
    fi
    cat >"$f" <<EOF
# ${APP_MANAGED_MARK}
/var/log/mail.log
/var/log/dovecot.log {
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
    postrotate
        systemctl reload postfix >/dev/null 2>&1 || true
        doveadm log reopen >/dev/null 2>&1 || true
    endscript
}
${APP_LOG}/*.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    copytruncate
}
EOF
    chmod 0644 "$f"
}

cmd_test_tls() {
    require_config
    local host="${1:-$MAIL_HOSTNAME}"
    header "TLS check for ${host}"
    (openssl s_client -starttls smtp -connect "${host}:25" -brief </dev/null) 2>&1 | grep -Ei 'protocol|verify|cipher' || true
    echo '---'
    (openssl s_client -connect "${host}:993" -brief </dev/null) 2>&1 | grep -Ei 'protocol|verify|cipher' || true
    echo '---'
    curl -sS -I "https://${host}" | head -n 5 || true
}
