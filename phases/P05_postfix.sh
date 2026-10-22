#!/usr/bin/env bash
PHASE_REQUIRES=""

phase_P05() {
    header "P05 postfix"
    postfix_configure
    svc_enable_now postfix
    log_info "Postfix is ready."
}
