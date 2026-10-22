#!/usr/bin/env bash
# phases/P06_dovecot.sh - Dovecot 2.3 configuration and LMTP/SASL wiring.
PHASE_REQUIRES="mailbox"

phase_P06() {
    header "P06 dovecot"
    dovecot_configure
    svc_enable_now dovecot
    log_info "Dovecot is ready."
}
