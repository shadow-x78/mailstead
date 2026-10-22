#!/usr/bin/env bats
# tests/components.bats - preset and dependency resolution.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export APP_ROOT="$ROOT"
    # lib/common.sh defines run(); preserve bats' run so it can capture status.
    if declare -f run >/dev/null 2>&1; then _BATS_RUN="$(declare -f run)"; fi
    # shellcheck source=/dev/null
    source "$ROOT/lib/brand.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    if [[ -n "${_BATS_RUN:-}" ]]; then eval "$_BATS_RUN"; fi
    # shellcheck source=/dev/null
    source "$ROOT/lib/components.sh"
    APP_ETC="$(mktemp -d)"
    export APP_LOG_DIR="$APP_ETC"
    export LOG_FILE="$APP_ETC/mailstead.log"
    DRY_RUN=1
    ASSUME_YES=1
}

teardown() { rm -rf "$APP_ETC"; }

@test "standard preset enables webmail, autoconfig and signatures" {
    components_defaults
    apply_preset standard
    [ "$(comp_get webmail)" = "roundcube" ]
    [ "$(comp_get webserver)" = "nginx" ]
    [ "$(comp_get autoconfig)" = "all" ]
    [ "$(comp_get signatures)" = "client" ]
}

@test "send-only disables mailbox-dependent components" {
    components_defaults
    apply_preset send-only
    resolve_components >/dev/null
    [ "$(comp_get mailbox)" = "no" ]
    [ "$(comp_get webmail)" = "none" ]
    [ "$(comp_get spam)" = "none" ]
    [ "$(comp_get signatures)" = "none" ]
}

@test "webmail forces a webserver and database" {
    components_defaults
    comp_set mailbox yes
    comp_set webmail roundcube
    comp_set webserver none
    comp_set db none
    resolve_components >/dev/null
    [ "$(comp_get webserver)" = "nginx" ]
    [ "$(comp_get db)" = "mariadb" ]
}

@test "mailbox without db is an error in v1" {
    components_defaults
    comp_set mailbox yes
    comp_set db none
    run resolve_components
    [ "$status" -ne 0 ]
}

@test "signatures=server requires dkim and mailbox" {
    components_defaults
    comp_set signatures server
    comp_set dkim none
    run resolve_components
    [ "$status" -ne 0 ]
}

@test "phase requirements skip disabled components" {
    components_defaults
    comp_set webmail none
    run phase_requires_check "webmail"
    [ "$status" -ne 0 ]
    [[ "$output" == skipped:* ]]
}

@test "phase requirements handle multiple space-separated components" {
    components_defaults
    comp_set webserver nginx
    comp_set webmail roundcube
    run phase_requires_check "webserver webmail"
    [ "$status" -eq 0 ]
    comp_set webmail none
    run phase_requires_check "webserver webmail"
    [ "$status" -ne 0 ]
}

# Regression for IFS=$'\n\t' (set by the dispatcher): multi-word requirements
# must still be split on spaces.
@test "phase requirements split on spaces under dispatcher IFS" {
    run bash -c '
        set -Eeuo pipefail
        IFS=$'"'"'\n\t'"'"'
        APP_ROOT="$1"; LOG_FILE="$2"; DRY_RUN=1
        . "$APP_ROOT/lib/brand.sh"
        . "$APP_ROOT/lib/common.sh"
        . "$APP_ROOT/lib/components.sh"
        components_defaults
        comp_set webserver nginx
        comp_set webmail roundcube
        phase_requires_check "webserver webmail"
    ' _ "$ROOT" "$APP_ETC/mailstead.log"
    [ "$status" -eq 0 ]
}