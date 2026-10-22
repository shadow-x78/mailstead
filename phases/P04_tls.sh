#!/usr/bin/env bash
PHASE_REQUIRES=""

phase_P04() {
    header "P04 certificates"
    if [[ "$(comp_get tls)" == "selfsigned" ]]; then
        tls_configure
    elif [[ "$(comp_get tls)" == "existing" ]]; then
        tls_configure
    else
        if [[ "$(comp_get webserver)" == "nginx" ]]; then
            nginx_common_settings
            nginx_write_acme_vhost
        fi
        tls_configure
    fi
    log_info "certificates are ready (mode=$(state_get CERT_MODE 2>/dev/null || printf '?'))."
}
