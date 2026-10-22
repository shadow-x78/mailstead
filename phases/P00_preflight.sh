#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Preflight Phase
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

PHASE_REQUIRES=""

phase_P00() {
    require_root
    header "P00 preflight"
    preflight_hostname
    preflight_resources
    preflight_ports
    preflight_outbound_25
    preflight_dns
}
