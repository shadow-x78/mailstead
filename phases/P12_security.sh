#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Security Hardening Phase
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

PHASE_REQUIRES=""

phase_P12() {
    header "P12 security"
    security_configure
    log_info "hardening is ready."
}
