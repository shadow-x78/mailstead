#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Autoconfiguration Setup Phase
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

PHASE_REQUIRES="autoconfig"

phase_P11b() {
    header "P11b autoconfig/autodiscover"
    autoconfig_add_domain "$PRIMARY_DOMAIN" "$PRIMARY_DOMAIN"
    log_info "autoconfig configured. Test with: ${APP_CMD} test-autoconfig ${ADMIN_EMAIL}"
}
