#!/usr/bin/env bash
# phases/P16_report.sh - final status and advisory output.
PHASE_REQUIRES=""

phase_P16() {
    header "P16 report"
    if ((DRY_RUN)); then
        # A dry-run never persists the config file and queries no live
        # services, so cmd_status (which requires both) is skipped; it would
        # otherwise abort the whole pipeline via require_config's die/exit.
        log_info "[dry-run] the preview is complete. After a real install, run '${APP_CMD} doctor'."
        return 0
    fi
    cmd_status 2>/dev/null || true
    log_info "run '${APP_CMD} doctor' for a full check."
}
