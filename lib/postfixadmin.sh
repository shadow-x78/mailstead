#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - PostfixAdmin Web Interface
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

# shellcheck shell=bash

pfa_dir() { printf '%s/postfixadmin' "$(path web_root)"; }

pfa_docroot() {
    local dir
    dir="$(pfa_dir)"
    if [[ -d "${dir}/public" ]]; then printf '%s/public' "$dir"; else printf '%s' "$dir"; fi
}

postfixadmin_configure() {
    local dir pfa_pw setup_hash
    dir="$(pfa_dir)"
    load_versions

    local cache="${APP_LIB}/cache/postfixadmin-${POSTFIXADMIN_VERSION}.tar.gz"
    download_verified "$POSTFIXADMIN_URL" "$cache" "$POSTFIXADMIN_SHA256"

    if ((DRY_RUN)); then
        log_info "[dry-run] install postfixadmin to ${dir}"
        return 0
    fi

    local tmp inner
    tmp="$(mktemp -d)"
    tar -xzf "$cache" -C "$tmp"
    inner="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)"
    [[ -n "$inner" ]] || die "unexpected tarball layout for PostfixAdmin."
    ensure_dir "$dir" 0755 root:root
    cp -a "${inner}/." "$dir/"
    rm -rf "$tmp"

    pfa_pw="$(secret_ensure db_postfixadmin)"
    db_sql_root "CREATE USER IF NOT EXISTS 'postfixadmin'@'127.0.0.1' IDENTIFIED BY '$(sql_quote "$pfa_pw")';"
    db_sql_root "ALTER USER 'postfixadmin'@'127.0.0.1' IDENTIFIED BY '$(sql_quote "$pfa_pw")';"
    db_sql_root "GRANT ALL PRIVILEGES ON mailserver.* TO 'postfixadmin'@'127.0.0.1';"
    db_sql_root "FLUSH PRIVILEGES;"

    setup_hash="$(php -r 'echo password_hash($argv[1], PASSWORD_DEFAULT);' "$(gen_password 24)" 2>/dev/null || printf '')"
    DB_PFA_PW="$pfa_pw"
    SETUP_HASH="$setup_hash"
    TPL_VARS="DB_PFA_PW SETUP_HASH ADMIN_EMAIL"
    backup_file "${dir}/config.local.php"
    render_template "${APP_ROOT}/templates/php/postfixadmin.config.local.php.tpl" \
        "${dir}/config.local.php" 0640 root:"$(web_user)"

    mkdir -p "${dir}/templates_c"
    chown -R "$(web_user)":"$(web_user)" "${dir}/templates_c"

    postfixadmin_schema "$dir"
    postfixadmin_create_admin
    log_info "installed PostfixAdmin ${POSTFIXADMIN_VERSION} to ${dir}."
}

postfixadmin_schema() {
    local dir="$1"
    local docroot
    docroot="$(pfa_docroot)"
    if [[ -f "${docroot}/upgrade.php" ]]; then
        php "${docroot}/upgrade.php" >/dev/null 2>&1 && {
            log_info "PostfixAdmin schema applied via upgrade.php."
            return 0
        }
    fi
    if [[ -f "${dir}/public/upgrade.php" ]]; then
        php "${dir}/public/upgrade.php" >/dev/null 2>&1 && {
            log_info "PostfixAdmin schema applied."
            return 0
        }
    fi
    log_warn "could not apply the PostfixAdmin schema automatically; complete the setup step in the browser, then re-run ${APP_CMD} doctor."
}

postfixadmin_create_admin() {
    local pw
    local cli
    cli="$(pfa_cli_path)"
    [[ -x "$cli" ]] || {
        log_warn "postfixadmin-cli not found; create the admin from the web interface."
        return 0
    }
    pw="$(secret_ensure admin_mailbox)"
    [[ -n "$ADMIN_EMAIL" ]] || {
        log_warn "ADMIN_EMAIL is not set; skipping admin creation."
        return 0
    }
    db_add_admin "$ADMIN_EMAIL" "$pw" 2>/dev/null ||
        log_warn "could not create the PostfixAdmin admin automatically (it may already exist)."
}
