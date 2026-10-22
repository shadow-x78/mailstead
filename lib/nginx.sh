#!/usr/bin/env bash
# lib/nginx.sh - Nginx vhosts, shared TLS/security settings and the PHP-FPM pool.
# shellcheck shell=bash

nginx_conf_dir() { path nginx_conf_d; }

nginx_reload_safe() {
    local bin
    bin="$(path nginx_bin)"
    if ((DRY_RUN)); then
        log_info "[dry-run] nginx -t && reload"
        return 0
    fi
    "$bin" -t || die "nginx -t failed; not reloaded."
    systemctl reload nginx || die "systemctl reload nginx failed"
}

nginx_ensure_conf_d_include() {
    local bin main
    bin="$(path nginx_bin)"
    if [[ ! -x "$bin" ]]; then
        # In a dry run on a clean host nginx is not installed yet (P01 would
        # install it); only a real run may require the binary to be present.
        ((DRY_RUN)) || die "nginx is not installed."
        return 0
    fi
    main="/etc/nginx/nginx.conf"
    if grep -q 'conf\.d/\*\.conf' "$main" 2>/dev/null; then
        return 0
    fi
    backup_file "$main"
    if ((DRY_RUN)); then
        log_info "[dry-run] add conf.d include to nginx.conf"
        return 0
    fi
    # Insert a guarded include inside http {} without duplicating it.
    awk '
        { print }
        /^[[:space:]]*http[[:space:]]*\{/ && !done { print "    include /etc/nginx/conf.d/*.conf;"; done=1 }
    ' "$main" >"${main}.tmp" && mv -f "${main}.tmp" "$main"
}

# Shared http-level settings (server_tokens, TLS protocols/ciphers).
nginx_common_settings() {
    local dst
    dst="$(nginx_conf_dir)/00-${APP_SLUG}-common.conf"
    if ((DRY_RUN)); then
        log_info "[dry-run] write ${dst}"
        return 0
    fi
    ensure_dir "$(nginx_conf_dir)"
    cat >"$dst" <<EOF
# ${APP_MANAGED_MARK}
server_tokens off;
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
ssl_session_tickets off;
# ssl_stapling intentionally disabled (Let's Encrypt ended OCSP).
limit_req_zone \$binary_remote_addr zone=autodiscover:10m rate=5r/s;
EOF
    chmod 0644 "$dst"
}

# nginx_write_from_template NAME TEMPLATE
_nginx_render() {
    local name="$1" tpl="$2"
    render_template "${APP_ROOT}/templates/nginx/${tpl}" \
        "$(nginx_conf_dir)/${APP_SLUG}-${name}.conf" 0644 root:root
}

# Temporary HTTP-only vhost used to bootstrap ACME (P04).
nginx_write_acme_vhost() {
    ALL_HOSTNAMES="${MAIL_HOSTNAME} ${PRIMARY_DOMAIN} www.${PRIMARY_DOMAIN}"
    if [[ "$(comp_get dashboard)" != "none" ]]; then
        ALL_HOSTNAMES+=" admin.${PRIMARY_DOMAIN}"
    fi
    TPL_VARS="ALL_HOSTNAMES"
    _nginx_render acme acme-http.conf.tpl
    nginx_ensure_conf_d_include
    nginx_reload_safe
}

# Final mail (Roundcube) vhost.
nginx_write_mail_vhost() {
    local docroot
    tls_ensure_vars
    docroot="$(roundcube_docroot 2>/dev/null || printf '%s/roundcube' "$(path web_root)")"
    ROUNDCUBE_DOCROOT="$docroot"
    PHP_SOCKET="$(nginx_php_socket)"
    WEB_USER="$(web_user)"
    TPL_VARS="MAIL_HOSTNAME PRIMARY_DOMAIN TLS_CERT_FILE TLS_KEY_FILE ROUNDCUBE_DOCROOT PHP_SOCKET WEB_USER APP_SLUG APP_LIB"
    _nginx_render mail mail.conf.tpl
}

# Admin (PostfixAdmin + Rspamd proxy) vhost.
nginx_write_admin_vhost() {
    tls_ensure_vars
    ADMIN_HOSTNAME="admin.${PRIMARY_DOMAIN}"
    PFA_DOCROOT="$(pfa_docroot 2>/dev/null || printf '%s/postfixadmin/public' "$(path web_root)")"
    PHP_SOCKET="$(nginx_php_socket)"
    ADMIN_ALLOW_IP="${ADMIN_ALLOW_IP:-}"
    local block=""
    if [[ -n "$ADMIN_ALLOW_IP" ]]; then
        local ip
        local -a ips=()
        IFS=',' read -r -a ips <<<"$ADMIN_ALLOW_IP"
        for ip in "${ips[@]+"${ips[@]}"}"; do
            block+="    allow ${ip};"$'\n'
        done
        block+="    deny all;"
    fi
    ADMIN_ALLOW_IP_BLOCK="$block"
    TPL_VARS="ADMIN_HOSTNAME TLS_CERT_FILE TLS_KEY_FILE PFA_DOCROOT PHP_SOCKET ADMIN_ALLOW_IP_BLOCK"
    _nginx_render admin admin.conf.tpl
}

nginx_remove_vhost() {
    local name="$1"
    local f
    f="$(nginx_conf_dir)/${APP_SLUG}-${name}.conf"
    if [[ -f "$f" ]]; then
        backup_file "$f"
        ((DRY_RUN)) || rm -f -- "$f"
        log_info "removed vhost: ${f}"
    fi
}

# ---- PHP-FPM ----
nginx_php_socket() {
    printf '%s/%s-php.sock' "$(path php_fpm_socket_dir)" "$APP_SLUG"
}

nginx_php_pool() {
    local pooldir socket f
    pooldir="$(path php_fpm_pool_dir)"
    socket="$(nginx_php_socket)"
    f="${pooldir}/${APP_SLUG}.conf"
    WEB_USER="$(web_user)"
    PHP_SOCKET="$socket"
    TPL_VARS="APP_SLUG WEB_USER PHP_SOCKET"
    ensure_dir "$pooldir"
    ensure_dir "$(path php_fpm_socket_dir)" 0755 root:root
    render_template "${APP_ROOT}/templates/php/php-fpm-pool.conf.tpl" "$f" 0644 root:root
    # Validate pool config and restart PHP-FPM (pool add requires restart).
    local php_svc
    php_svc="$(svc_name php-fpm)"
    if ((!DRY_RUN)); then
        systemctl restart "$php_svc" || die "failed to start ${php_svc} after adding pool"
    fi
}
