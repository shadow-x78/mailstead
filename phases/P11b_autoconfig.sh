#!/usr/bin/env bash
# phases/P11b_autoconfig.sh - Thunderbird autoconfig + Outlook Autodiscover.
PHASE_REQUIRES="autoconfig"

phase_P11b() {
    header "P11b autoconfig/autodiscover"
    autoconfig_add_domain "$PRIMARY_DOMAIN" "$PRIMARY_DOMAIN"
    log_info "autoconfig configured. Test with: ${APP_CMD} test-autoconfig ${ADMIN_EMAIL}"
}
