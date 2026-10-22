#!/usr/bin/env bash
# phases/P00_preflight.sh - environment, hostname and DNS sanity checks.
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
