#!/usr/bin/env bash
# phases/P05_postfix.sh - Postfix main.cf/master.cf/SQL maps and transport.
PHASE_REQUIRES=""

phase_P05() {
    header "P05 postfix"
    postfix_configure
    svc_enable_now postfix
    log_info "Postfix is ready."
}
