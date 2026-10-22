#!/usr/bin/env bash
# phases/P13_dns.sh - generate and save DNS records for the primary domain.
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
