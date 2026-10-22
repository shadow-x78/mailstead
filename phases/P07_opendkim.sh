#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - OpenDKIM Setup Phase
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

PHASE_REQUIRES="dkim"

phase_P07() {
    header "P07 opendkim"
    dkim_configure
    dkim_add_domain "$PRIMARY_DOMAIN"
    svc_enable_now opendkim
    log_info "OpenDKIM is ready; print the record with: ${APP_CMD} dkim-show ${PRIMARY_DOMAIN}"
}
