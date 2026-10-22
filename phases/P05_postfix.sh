#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Postfix Setup Phase
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

PHASE_REQUIRES=""

phase_P05() {
    header "P05 postfix"
    postfix_configure
    svc_enable_now postfix
    log_info "Postfix is ready."
}
