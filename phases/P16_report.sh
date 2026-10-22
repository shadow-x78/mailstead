#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Final Report Phase
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

PHASE_REQUIRES=""

phase_P16() {
    header "P16 report"
    if ((DRY_RUN)); then
        log_info "[dry-run] the preview is complete. After a real install, run '${APP_CMD} doctor'."
        return 0
    fi
    cmd_status 2>/dev/null || true
    log_info "run '${APP_CMD} doctor' for a full check."
}
