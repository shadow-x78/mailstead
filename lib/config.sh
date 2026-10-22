#!/usr/bin/env bash
# shellcheck shell=bash

CONF_FILE_DEFAULT() { printf '%s/mailstead.conf' "$APP_ETC"; }

config_set() {
    local key="$1" val="$2" f
    f="$(CONF_FILE_DEFAULT)"
    if ((DRY_RUN)); then
        log_info "[dry-run] config ${key}=${val}"
        return 0
    fi
    mkdir -p "$APP_ETC"
    touch "$f"
    chmod 0600 "$f"
    local tmp
    tmp="$(mktemp)"
    grep -vE "^${key}=" "$f" >"$tmp" 2>/dev/null || true
    printf '%s=%s\n' "$key" "$val" >>"$tmp"
    mv -f -- "$tmp" "$f"
}

config_load() {
    local f
    f="$(CONF_FILE_DEFAULT)"
    if [[ ! -r "$f" ]]; then
        return 1
    fi
    local line key val
    while IFS= read -r line; do
        [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
        key="${line%%=*}"
        val="${line#*=}"
        printf -v "$key" '%s' "$val"
    done <"$f"
    MAIL_HOSTNAME="${MAIL_HOSTNAME:-}"
    PRIMARY_DOMAIN="${PRIMARY_DOMAIN:-}"
    ADMIN_EMAIL="${ADMIN_EMAIL:-}"
    return 0
}

require_config() {
    config_load || die "no ${APP_NAME} configuration found. Run '${APP_CMD} install' first." "$EX_ERR"
    [[ -n "${MAIL_HOSTNAME:-}" && -n "${PRIMARY_DOMAIN:-}" ]] ||
        die "incomplete configuration in ${APP_ETC}/${APP_SLUG}.conf" "$EX_ERR"
}
