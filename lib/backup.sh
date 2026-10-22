#!/usr/bin/env bash
# lib/backup.sh - backup, restore, uninstall (P15) and scheduled backups.
# shellcheck shell=bash

backup_paths() {
    cat <<EOF
/etc/postfix
/etc/dovecot
/etc/opendkim
/etc/rspamd/local.d
/etc/nginx
${APP_ETC}
/etc/letsencrypt
/var/vmail
/var/www/roundcube/config
/var/www/postfixadmin/config.local.php
${APP_LIB}/signatures
${APP_LIB}/web
${APP_LIB}/domains.list
EOF
}

backup_run() {
    local dest="${1:-${APP_BACKUP}}"
    ensure_dir "$dest" 0700 root:root
    local ts archive
    ts="$(date +%Y%m%dT%H%M%S)"
    archive="${dest}/${APP_SLUG}-${ts}.tar.gz"
    if ((DRY_RUN)); then
        log_info "[dry-run] backup -> ${archive}"
        return 0
    fi

    local staging
    staging="$(mktemp -d)"
    local dump="${staging}/database.sql"
    : >"$dump"
    if command -v mysqldump >/dev/null 2>&1; then
        local db
        for db in mailserver roundcube; do
            if mysql -N -B -e "SHOW DATABASES LIKE '${db}';" 2>/dev/null | grep -qx "$db"; then
                mysqldump --single-transaction --databases "$db" >>"$dump" 2>/dev/null ||
                    log_warn "mysqldump failed for ${db}."
            fi
        done
    fi

    local -a paths=()
    mapfile -t paths < <(backup_paths)
    local -a existing=()
    local p
    for p in "${paths[@]}"; do
        [[ -e "$p" ]] && existing+=(-C / "${p#/}")
    done

    tar -czf "$archive" -C "$staging" database.sql "${existing[@]+"${existing[@]}"}" 2>/dev/null ||
        tar -czf "$archive" -C "$staging" database.sql
    chmod 0600 "$archive"
    sha256sum "$archive" >"${archive}.sha256"
    rm -rf "$staging"
    log_info "backup: ${archive}"
    _backup_prune "$dest"
}

_backup_prune() {
    local dest="$1"
    local -a olds=()
    mapfile -t olds < <(
        find "$dest" -maxdepth 1 -name "${APP_SLUG}-*.tar.gz" -printf '%T@ %p\n' 2>/dev/null |
            sort -rn | awk 'NR>7 {sub(/^[^ ]+ /, ""); print}'
    )
    local old
    for old in "${olds[@]}"; do
        [[ -n "$old" ]] || continue
        rm -f -- "$old" "${old}.sha256"
    done
}

backup_schedule() {
    local unit="/etc/systemd/system/${APP_SLUG}-backup.service"
    local timer="/etc/systemd/system/${APP_SLUG}-backup.timer"
    if ((DRY_RUN)); then
        log_info "[dry-run] install backup timer"
        return 0
    fi
    cat >"$unit" <<EOF
# ${APP_MANAGED_MARK}
[Unit]
Description=${APP_NAME} daily backup
[Service]
Type=oneshot
ExecStart=/usr/local/bin/${APP_CMD} backup
EOF
    cat >"$timer" <<EOF
# ${APP_MANAGED_MARK}
[Unit]
Description=${APP_NAME} daily backup timer
[Timer]
OnCalendar=daily
Persistent=true
[Install]
WantedBy=timers.target
EOF
    systemctl daemon-reload
    systemctl enable --now "${APP_SLUG}-backup.timer" >/dev/null 2>&1 || true
    log_info "scheduled the daily backup (7 copies)."
}

restore_run() {
    local file="$1"
    [[ -r "$file" ]] || die "backup file not found: ${file}"
    if [[ -r "${file}.sha256" ]]; then
        (cd "$(dirname -- "$file")" && sha256sum -c "$(basename -- "${file}.sha256")") ||
            die "failed to verify the backup sha256."
    fi
    if ((DRY_RUN)); then
        log_info "[dry-run] restore ${file}"
        return 0
    fi

    log_info "stopping services before restore..."
    _stop_mail_services

    local staging
    staging="$(mktemp -d)"
    tar -xzf "$file" -C "$staging"
    if [[ -f "${staging}/database.sql" ]] && command -v mysql >/dev/null 2>&1; then
        mysql <"${staging}/database.sql" || log_warn "could not import the database."
    fi
    # Restore each recorded path (skip the database.sql entry).
    (cd "$staging" && find . -mindepth 1 -maxdepth 1 ! -name database.sql -exec cp -a -- {} / \;)
    rm -rf "$staging"

    chown -R vmail:vmail /var/vmail 2>/dev/null || true
    log_info "restore complete; starting services..."
    _start_mail_services
}

_stop_mail_services() {
    local s
    for s in postfix dovecot opendkim rspamd nginx; do
        systemctl stop "$s" 2>/dev/null || true
    done
}

_start_mail_services() {
    local s
    for s in postfix dovecot opendkim rspamd; do
        systemctl start "$s" 2>/dev/null || true
    done
    if [[ "$(comp_get webserver)" != "none" ]]; then systemctl start nginx 2>/dev/null || true; fi
}

uninstall_run() {
    local purge="${1:-0}" vmail_confirm="${2:-0}"
    if [[ "$purge" == "1" ]]; then
        log_warn "taking a final backup before removal..."
        backup_run "${APP_BACKUP}"
        _stop_mail_services
        local s
        for s in postfix dovecot opendkim rspamd nginx fail2ban; do
            systemctl disable --now "$s" 2>/dev/null || true
        done
        _uninstall_packages
        _uninstall_managed_paths
        if [[ "$vmail_confirm" == "1" ]]; then
            log_warn "deleting /var/vmail (user data) with explicit confirmation."
            ((DRY_RUN)) || rm -rf -- /var/vmail
            _uninstall_vmail_user
            log_info "full removal complete: packages + config + app + user data."
        else
            log_warn "removed the config, packages and app. /var/vmail (user data) was kept."
            log_warn "to delete the mail permanently: ${APP_CMD} uninstall --purge --purge-mail --yes"
        fi
    else
        _stop_mail_services
        local s
        for s in postfix dovecot opendkim rspamd nginx fail2ban; do
            systemctl disable "$s" 2>/dev/null || true
        done
        log_info "services stopped and disabled (without --purge). The config and packages were kept."
    fi
}

# _uninstall_packages - remove only the packages Mailstead itself installed.
# The list is captured at install time (P01 -> state INSTALLED_PKGS) so that
# pre-existing shared packages (nginx, mariadb, ...) are never removed.
_uninstall_packages() {
    local tracked
    tracked="$(state_get INSTALLED_PKGS 2>/dev/null || printf '')"
    if [[ -z "${tracked// /}" ]]; then
        log_warn "no record of the packages ${APP_NAME} installed; no packages will be removed (delete them manually if you want)."
        return 0
    fi
    local -a reals=()
    read -r -a reals <<<"$tracked"
    [[ "${#reals[@]}" -gt 0 ]] || return 0
    log_warn "removing only the packages ${APP_NAME} installed: ${reals[*]}"
    pkg_remove "${reals[@]}" || log_warn "could not remove some packages; check the package manager output."
}

# _uninstall_managed_paths - delete every file/directory Mailstead created:
# config, state, logs, backups, the tool itself, web apps and systemd units.
# Never touches /etc/letsencrypt wholesale (shared) or /var/vmail (user data).
# The managed-path list is defined once so the dry-run preview and the real
# removal stay in sync.
_uninstall_managed_list() {
    local p
    for p in \
        "$APP_ETC" "$APP_LIB" "$APP_LOG" "$APP_BACKUP" "$APP_OPT" "$APP_LIBEXEC" \
        /etc/postfix /etc/dovecot /etc/opendkim /etc/rspamd \
        /var/spool/postfix /var/www/roundcube /var/www/postfixadmin \
        "/etc/systemd/system/${APP_SLUG}-backup.service" \
        "/etc/systemd/system/${APP_SLUG}-backup.timer" \
        /etc/nginx/.htpasswd-rspamd "/usr/local/bin/${APP_CMD}"; do
        [[ -n "$p" ]] && printf '%s\n' "$p"
    done
}

_uninstall_managed_paths() {
    if ((DRY_RUN)); then
        log_info "[dry-run] would remove these managed paths:"
        while IFS= read -r p; do
            printf '  - %s\n' "$p"
        done < <(_uninstall_managed_list)
        return 0
    fi
    local p
    while IFS= read -r p; do
        [[ -e "$p" ]] && rm -rf -- "$p"
    done < <(_uninstall_managed_list)
    # Nginx vhosts managed by Mailstead.
    local c
    for c in /etc/nginx/conf.d/"${APP_SLUG}"-*.conf; do
        [[ -e "$c" ]] && rm -f -- "$c"
    done
    systemctl daemon-reload 2>/dev/null || true
}

# _uninstall_vmail_user - remove the vmail system user (last step).
_uninstall_vmail_user() {
    ((DRY_RUN)) && return 0
    userdel vmail 2>/dev/null || true
}

cmd_backup() {
    local dest="${APP_BACKUP}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dest)
                dest="${2:-}"
                shift 2
                ;;
            --schedule)
                backup_schedule
                return 0
                ;;
            *) die "unknown option: $1" "$EX_USAGE" ;;
        esac
    done
    require_config
    backup_run "$dest"
}

cmd_restore() {
    require_config
    local file="" second=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes) shift ;;
            --vmail)
                second=1
                shift
                ;;
            *)
                file="$1"
                shift
                ;;
        esac
    done
    [[ -n "$file" ]] || die "usage: ${APP_CMD} restore FILE --yes" "$EX_USAGE"
    confirm "the system will be restored from ${file} and the current data replaced. Continue?" || die "cancelled." "$EX_OK"
    restore_run "$file"
    "$APP_ROOT/mailstead" doctor || true
}

cmd_uninstall() {
    local purge=0 vmail=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --purge)
                purge=1
                shift
                ;;
            --purge-mail)
                vmail=1
                shift
                ;;
            --yes) shift ;;
            *) die "unknown option: $1" "$EX_USAGE" ;;
        esac
    done
    confirm "confirm stopping/disabling the ${APP_NAME} services?" || die "cancelled." "$EX_OK"
    if [[ "$purge" == "1" && "$vmail" == "1" ]]; then
        confirm "warning: everything will be deleted, including /var/vmail (user data) and the app itself. Final confirmation?" ||
            die "cancelled." "$EX_OK"
    elif [[ "$purge" == "1" ]]; then
        confirm "the config, packages and app will be removed (/var/vmail data will be kept). Continue?" || vmail=0
    fi
    uninstall_run "$purge" "$vmail"
}
