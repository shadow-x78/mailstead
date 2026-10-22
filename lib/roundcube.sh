#!/usr/bin/env bash
# lib/roundcube.sh - Roundcube webmail install and configuration (P10).
# shellcheck shell=bash

roundcube_dir() { printf '%s/roundcube' "$(path web_root)"; }

roundcube_docroot() {
    local dir
    dir="$(roundcube_dir)"
    if [[ -d "${dir}/public_html" ]]; then printf '%s/public_html' "$dir"; else printf '%s' "$dir"; fi
}

roundcube_logs_dir() { printf '%s/logs' "$(roundcube_dir)"; }

roundcube_configure() {
    local dir docroot pfa_pw
    dir="$(roundcube_dir)"
    docroot="$(roundcube_docroot)"

    load_versions
    ensure_dir "$(path web_root)" 0755 root:root

    # Fetch and verify the pinned tarball.
    local cache="${APP_LIB}/cache/roundcubemail-${ROUNDCUBE_VERSION}.tar.gz"
    download_verified "$ROUNDCUBE_URL" "$cache" "$ROUNDCUBE_SHA256"

    if ((DRY_RUN)); then
        log_info "[dry-run] install roundcube to ${dir}"
        return 0
    fi

    local tmp
    tmp="$(mktemp -d)"
    tar -xzf "$cache" -C "$tmp"
    local inner
    inner="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)"
    [[ -n "$inner" ]] || die "unexpected tarball layout for Roundcube."
    ensure_dir "$dir" 0755 root:root
    cp -a "${inner}/." "$dir/"
    rm -rf "$tmp"
    docroot="$(roundcube_docroot)"

    # Roundcube database and user.
    local rc_pw
    rc_pw="$(secret_ensure db_roundcube)"
    db_sql_root "CREATE DATABASE IF NOT EXISTS roundcube CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    db_sql_root "CREATE USER IF NOT EXISTS 'roundcube'@'127.0.0.1' IDENTIFIED BY '$(sql_quote "$rc_pw")';"
    db_sql_root "ALTER USER 'roundcube'@'127.0.0.1' IDENTIFIED BY '$(sql_quote "$rc_pw")';"
    db_sql_root "GRANT ALL PRIVILEGES ON roundcube.* TO 'roundcube'@'127.0.0.1';"
    db_sql_root "FLUSH PRIVILEGES;"

    # Main config.
    local rc_plugins="['archive','zipdownload','managesieve','password']"
    if [[ "$(comp_get signatures)" != "none" && -d "${APP_ROOT}/templates/php/mailstead_signature" ]]; then
        rc_plugins="['archive','zipdownload','managesieve','password','mailstead_signature']"
    fi
    RC_PLUGINS="$rc_plugins"
    DB_RC_PW="$rc_pw"
    RC_DES_KEY="$(secret_ensure rc_des_key 24)"
    TPL_VARS="DB_RC_PW MAIL_HOSTNAME RC_DES_KEY RC_PLUGINS"
    backup_file "${dir}/config/config.inc.php"
    render_template "${APP_ROOT}/templates/php/roundcube.config.inc.php.tpl" \
        "${dir}/config/config.inc.php" 0640 root:"$(web_user)"

    # Password plugin.
    DB_MAILPW_PW="$(secret_ensure db_mailpw)"
    TPL_VARS="DB_MAILPW_PW"
    backup_file "${dir}/plugins/password/config.inc.php"
    render_template "${APP_ROOT}/templates/php/roundcube.password.inc.php.tpl" \
        "${dir}/plugins/password/config.inc.php" 0640 root:"$(web_user)"

    roundcube_install_signature_plugin

    # Schema.
    (cd "$dir" && php bin/initdb.sh --dir=SQL) >/dev/null 2>&1 ||
        log_warn "php bin/initdb.sh did not run automatically; see the Roundcube docs to install the schema."

    roundcube_permissions
    rm -rf "${dir}/installer" 2>/dev/null || true
    log_info "installed Roundcube ${ROUNDCUBE_VERSION} to ${dir}."
}

roundcube_install_signature_plugin() {
    [[ "$(comp_get signatures)" != "none" ]] || return 0
    local src="${APP_ROOT}/templates/php/mailstead_signature"
    [[ -d "$src" ]] || return 0
    local dst
    dst="$(roundcube_dir)/plugins/mailstead_signature"
    ((DRY_RUN)) && {
        log_info "[dry-run] install signature plugin"
        return 0
    }
    ensure_dir "$dst" 0755 root:root
    cp -a "${src}/." "$dst/"
    POLICY="$(comp_get sig-policy)"
    TPL_VARS="APP_LIB POLICY"
    render_template "${src}/config.inc.php.tpl" "${dst}/config.inc.php" 0640 root:"$(web_user)"
    rm -f -- "${dst}/config.inc.php.tpl"
    chown -R root:"$(web_user)" "$dst"
}

roundcube_permissions() {
    local dir
    dir="$(roundcube_dir)"
    ((DRY_RUN)) && return 0
    local d
    for d in temp logs; do
        [[ -d "${dir}/${d}" ]] && chown -R "$(web_user)":"$(web_user)" "${dir}/${d}" && chmod -R 0700 "${dir}/${d}"
    done
    chown root:"$(web_user)" "${dir}/config" 2>/dev/null || true
    chmod 0750 "${dir}/config" 2>/dev/null || true
}

cmd_upgrade_web() {
    require_config
    load_versions
    header "Web update (Roundcube ${ROUNDCUBE_VERSION})"
    confirm "The installed version will be downloaded and the update applied. Continue?" || die "cancelled." "$EX_OK"

    backup_run "${APP_BACKUP}"
    local dir cache tmp inner
    dir="$(roundcube_dir)"
    cache="${APP_LIB}/cache/roundcubemail-${ROUNDCUBE_VERSION}.tar.gz"
    download_verified "$ROUNDCUBE_URL" "$cache" "$ROUNDCUBE_SHA256"

    if ((DRY_RUN)); then
        log_info "[dry-run] upgrade roundcube"
        return 0
    fi
    tmp="$(mktemp -d)"
    tar -xzf "$cache" -C "$tmp"
    inner="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)"
    (cd "$dir" && php bin/installto.sh "$inner") || log_warn "installto.sh finished with a warning."
    rm -rf "$tmp"
    roundcube_permissions
    nginx_reload_safe
    log_info "Roundcube updated."
}
