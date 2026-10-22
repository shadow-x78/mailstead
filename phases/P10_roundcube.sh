#!/usr/bin/env bash
# phases/P10_roundcube.sh - Roundcube webmail + mail vhost + PHP pool.
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
