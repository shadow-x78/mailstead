#!/usr/bin/env bash
# phases/P04_tls.sh - certificates (bootstrap with snakeoil, then real).
PHASE_REQUIRES=""

phase_P04() {
    header "P04 certificates"
    # Ensure the cert paths exist before Postfix/Dovecot start.
    if [[ "$(comp_get tls)" == "selfsigned" ]]; then
        tls_configure
    elif [[ "$(comp_get tls)" == "existing" ]]; then
        tls_configure
    else
        # Let's Encrypt: need Nginx webroot vhost when a web server is used.
        if [[ "$(comp_get webserver)" == "nginx" ]]; then
            nginx_common_settings
            nginx_write_acme_vhost
        fi
        tls_configure
    fi
    log_info "certificates are ready (mode=$(state_get CERT_MODE 2>/dev/null || printf '?'))."
}
