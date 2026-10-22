#!/usr/bin/env bash
PHASE_REQUIRES=""

phase_P15() {
    header "P15 backup"
    ensure_dir "$APP_BACKUP" 0700 root:root
    if [[ "${BACKUP_SCHEDULE:-0}" == "1" ]]; then
        backup_schedule
    else
        log_info "the daily backup is not scheduled (run: ${APP_CMD} backup --schedule)."
    fi
}
