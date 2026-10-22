#!/usr/bin/env bats
# tests/uninstall.bats - proves the "remove everything" uninstall flow.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export APP_ROOT="$ROOT"
    TMP="$(mktemp -d)"
    export APP_LOG_DIR="$TMP"
    export LOG_FILE="$TMP/mailstead.log"
    if declare -f run >/dev/null 2>&1; then _BATS_RUN="$(declare -f run)"; fi
    # shellcheck source=/dev/null
    source "$ROOT/lib/brand.sh"
    # Point the managed APP_* paths at the scratch dir so real paths are untouched.
    APP_ETC="$TMP/etc"; APP_LIB="$TMP/lib"; APP_LOG="$TMP/log"
    APP_BACKUP="$TMP/backup"; APP_OPT="$TMP/opt"; APP_LIBEXEC="$TMP/libexec"
    export APP_ETC APP_LIB APP_LOG APP_BACKUP APP_OPT APP_LIBEXEC
    export DRY_RUN=1
    ASSUME_YES=1
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    if [[ -n "${_BATS_RUN:-}" ]]; then eval "$_BATS_RUN"; fi
    # shellcheck source=/dev/null
    source "$ROOT/lib/backup.sh"
    # Stub the external side-effects so the test is hermetic.
    _stop_mail_services() { :; }
    _uninstall_packages() { :; }
    backup_run() { :; }
    systemctl() { :; }
    userdel() { :; }
    pkg_remove() { :; }
}

teardown() { rm -rf "$TMP"; }

_create_managed() {
    install -d -m 0755 -o "$(id -un)" -g "$(id -gn)" "$APP_ETC" "$APP_LIB" "$APP_LOG" \
        "$APP_BACKUP" "$APP_OPT" "$APP_LIBEXEC"
    printf 'x' >"$APP_ETC/mailstead.conf"
    printf 'x' >"$APP_OPT/mailstead"
    printf 'x' >"$APP_LIB/state.env"
}

@test "dry-run removes nothing and lists the managed paths" {
    _create_managed
    DRY_RUN=1
    run uninstall_run 1 1
    [ "$status" -eq 0 ]
    # Nothing was deleted in dry-run.
    [ -f "$APP_ETC/mailstead.conf" ]
    [ -f "$APP_OPT/mailstead" ]
    # The preview names the tool entrypoint and the web apps.
    run _uninstall_managed_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"/usr/local/bin/mailstead"* ]]
    [[ "$output" == *"/var/www/roundcube"* ]]
    [[ "$output" == *"$APP_OPT"* ]]
}

@test "managed list is complete (config, state, tool, units, web apps)" {
    run _uninstall_managed_list
    [ "$status" -eq 0 ]
    for p in "$APP_ETC" "$APP_LIB" "$APP_LOG" "$APP_BACKUP" "$APP_OPT" \
        /etc/postfix /etc/dovecot /etc/opendkim /etc/rspamd \
        /var/www/roundcube /var/www/postfixadmin \
        "/etc/systemd/system/mailstead-backup.timer" \
        /usr/local/bin/mailstead; do
        [[ "$output" == *"$p"* ]] || { echo "missing $p"; return 1; }
    done
}

@test "real deletion removes the managed directories" {
    # Skip on a host that actually runs mail (real /etc/postfix present).
    [ -d /etc/postfix ] && skip "running mail system; do not delete real paths"
    _create_managed
    DRY_RUN=0
    run _uninstall_managed_paths
    [ "$status" -eq 0 ]
    [ ! -e "$APP_ETC" ]
    [ ! -e "$APP_OPT" ]
    [ ! -e "$APP_LIB" ]
    [ ! -e "$APP_BACKUP" ]
}

@test "full remove-everything flow (purge + purge-mail) completes" {
    _create_managed
    DRY_RUN=1
    run cmd_uninstall --purge --purge-mail --yes
    [ "$status" -eq 0 ]
}