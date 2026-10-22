#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - PostfixAdmin Setup Phase
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

PHASE_REQUIRES="dashboard"

phase_P09() {
    header "P09 postfixadmin"
    nginx_php_pool
    postfixadmin_configure
    nginx_common_settings
    nginx_write_admin_vhost
    rspamd_htpasswd
    nginx_reload_safe
    log_info "PostfixAdmin is ready at admin.${PRIMARY_DOMAIN}."
}
