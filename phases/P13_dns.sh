#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - DNS Records Phase
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

PHASE_REQUIRES=""

phase_P13() {
    header "P13 dns"
    if ((DRY_RUN)); then
        log_info "[dry-run] dns-print"
        return 0
    fi
    ensure_dir "${APP_ETC}/dns" 0755 root:root
    dns_records_print "$PRIMARY_DOMAIN" >"${APP_ETC}/dns/${PRIMARY_DOMAIN}.txt"
    log_info "records saved to ${APP_ETC}/dns/${PRIMARY_DOMAIN}.txt"
}
