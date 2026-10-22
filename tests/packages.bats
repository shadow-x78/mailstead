#!/usr/bin/env bats
# tests/packages.bats - install-time package tracking for safe uninstall.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export APP_ROOT="$ROOT"
    TMP="$(mktemp -d)"
    export APP_LOG_DIR="$TMP"
    export LOG_FILE="$TMP/mailstead.log"
    if declare -f run >/dev/null 2>&1; then _BATS_RUN="$(declare -f run)"; fi
    # shellcheck source=/dev/null
    source "$ROOT/lib/brand.sh"
    APP_LIB="$TMP/lib"
    APP_ETC="$TMP/etc"
    APP_LIB_DIR="$TMP/lib"
    APP_ETC_DIR="$TMP/etc"
    mkdir -p "$APP_LIB_DIR" "$APP_ETC_DIR"
    export APP_LIB APP_ETC APP_LIB_DIR APP_ETC_DIR
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    if [[ -n "${_BATS_RUN:-}" ]]; then eval "$_BATS_RUN"; fi
    # shellcheck source=/dev/null
    source "$ROOT/lib/components.sh"
    # shellcheck source=/dev/null
    source "$ROOT/phases/P01_packages.sh"
    DRY_RUN=0
    ASSUME_YES=1
}

teardown() { rm -rf "$TMP"; }

@test "record_installed keeps only packages that were not pre-existing" {
    _p01_record_installed postfix nginx mariadb -- nginx
    run state_get INSTALLED_PKGS
    # The pre-existing 'nginx' is excluded; order follows the reals list.
    [ "$output" = "postfix mariadb " ]
}

@test "record_installed with nothing pre-existing keeps everything" {
    _p01_record_installed postfix dovecot --
    run state_get INSTALLED_PKGS
    [ "$output" = "postfix dovecot " ]
}

@test "record_installed is a no-op under --dry-run" {
    DRY_RUN=1
    _p01_record_installed postfix --
    run state_get INSTALLED_PKGS
    [ "$status" -ne 0 ]
}