#!/usr/bin/env bash
# phases/P08_rspamd.sh - Rspamd + Redis (inbound filtering, SPF/DKIM/DMARC).
PHASE_REQUIRES="spam"

phase_P08() {
    header "P08 rspamd"
    rspamd_configure
    svc_enable_now rspamd
    log_info "Rspamd is ready."
}
