#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Rspamd Spam Filter
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

# shellcheck shell=bash

rspamd_local_d() { path rspamd_local_d; }

kv_conf_file() {
    if [[ -f /etc/valkey/valkey.conf ]]; then
        printf '/etc/valkey/valkey.conf'
        return
    fi
    if [[ -f /etc/redis/redis.conf ]]; then
        printf '/etc/redis/redis.conf'
        return
    fi
    printf '/etc/redis/redis.conf'
}

kv_configure() {
    local f marker
    f="$(kv_conf_file)"
    marker="# ${APP_MANAGED_MARK}"
    if ((DRY_RUN)); then
        log_info "[dry-run] configure kv at ${f}"
        return 0
    fi
    if [[ ! -f "$f" ]]; then
        log_warn "kv config file not found (${f}); skipping Redis setup."
        return 0
    fi
    if ! grep -qF "$marker" "$f"; then
        backup_file "$f"
        cat >>"$f" <<EOF

$marker
bind 127.0.0.1 ::1
protected-mode yes
maxmemory 256mb
maxmemory-policy allkeys-lru
EOF
    fi
}

rspamd_configure() {
    kv_configure
    svc_enable_now kv

    local dir
    dir="$(rspamd_local_d)"
    ensure_dir "$dir" 0755 root:root

    local pw hash
    pw="$(secret_ensure rspamd_ui)"
    if ((DRY_RUN)); then
        hash='$2$DRYRUNHASHDRYRUNHASHDRYRUNHASH'
    else
        hash="$(rspamadm pw -p "$pw")"
    fi

    RSPAMD_PW_HASH="$hash"
    TPL_VARS="RSPAMD_PW_HASH"
    _rspamd_render worker-controller.inc.tpl

    TPL_VARS=""
    local t
    for t in redis.conf classifier-bayes.conf worker-proxy.inc actions.conf \
        milter_headers.conf dkim_signing.conf arc.conf; do
        _rspamd_render "$t.tpl"
    done

    if ((DRY_RUN)); then
        log_info "[dry-run] rspamadm configtest && restart"
        return 0
    fi
    rspamadm configtest >/dev/null 2>&1 || die "rspamadm configtest failed."
    systemctl restart rspamd || die "failed to start rspamd."
    wait_for_port 127.0.0.1 11332 10 || log_warn "rspamd milter is not listening on 11332."
    wait_for_port 127.0.0.1 11334 10 || log_warn "rspamd controller is not listening on 11334."
    state_set RSPAMD_UI_HASH "$hash"
}

_rspamd_render() {
    local tpl="$1"
    local name="${tpl%.tpl}"
    render_template "${APP_ROOT}/templates/rspamd/${tpl}" "$(rspamd_local_d)/${name}" 0644 root:root
}

rspamd_htpasswd() {
    local pw
    pw="$(secret_get rspamd_ui)" || return 0
    local f="/etc/nginx/.htpasswd-rspamd"
    if [[ ! -f "$f" ]] && ((!DRY_RUN)); then
        if command -v htpasswd >/dev/null 2>&1; then
            htpasswd -bc "$f" rspamd "$pw" >/dev/null 2>&1
        else
            printf 'admin:%s\n' "$(openssl passwd -apr1 "$pw")" >"$f"
        fi
        chmod 0640 "$f"
        chown root:nginx "$f" 2>/dev/null || chown root:"$(web_user)" "$f" 2>/dev/null || true
    fi
}
