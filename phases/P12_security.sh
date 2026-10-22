#!/usr/bin/env bash
PHASE_REQUIRES=""

phase_P12() {
    header "P12 security"
    security_configure
    log_info "hardening is ready."
}
