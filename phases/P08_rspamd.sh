#!/usr/bin/env bash
PHASE_REQUIRES="spam"

phase_P08() {
    header "P08 rspamd"
    rspamd_configure
    svc_enable_now rspamd
    log_info "Rspamd is ready."
}
