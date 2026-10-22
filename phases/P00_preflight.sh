#!/usr/bin/env bash
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
