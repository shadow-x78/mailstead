#!/usr/bin/env bash
PHASE_REQUIRES="webmail"

phase_P10() {
    header "P10 roundcube"
    nginx_php_pool
    roundcube_configure
    nginx_common_settings
    nginx_write_mail_vhost
    nginx_reload_safe
    log_info "Roundcube is ready at https://${MAIL_HOSTNAME}/."
}
