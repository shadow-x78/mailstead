#!/usr/bin/env bash
PHASE_REQUIRES=""

phase_P03() {
    if [[ "$(comp_get db)" != "mariadb" ]]; then
        log_info "P03: db=none (skipping the database)."
        return 0
    fi
    header "P03 database"
    db_configure

    if [[ "$(comp_get mailbox)" == "yes" ]]; then
        db_add_domain "$PRIMARY_DOMAIN"
        cli_standard_aliases "$PRIMARY_DOMAIN"
        if ! db_mailbox_exists "${ADMIN_EMAIL:-postmaster@${PRIMARY_DOMAIN}}"; then
            local pw
            pw="$(secret_ensure admin_mailbox)"
            db_add_mailbox "${ADMIN_EMAIL:-postmaster@${PRIMARY_DOMAIN}}" "$pw" 0 "Administrator"
        fi
    fi
    log_info "the database is ready and the primary domain is registered."
}
