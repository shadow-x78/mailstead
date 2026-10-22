#!/usr/bin/env bash
PHASE_REQUIRES="mailbox"

phase_P06() {
    header "P06 dovecot"
    dovecot_configure
    svc_enable_now dovecot
    log_info "Dovecot is ready."
}
