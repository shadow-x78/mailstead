#!/usr/bin/env bats
# ─────────────────────────────────────────────
# Mailstead - End-to-End Installer Tests
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

# Runs the real cmd_install (parsing -> resolve -> config -> P00..P16) with
# DRY_RUN=1 against a scratch filesystem so it must complete without needing
# root, systemd, or a real install. This is the "does the whole flow work"
# check that the VM test (tests/vm/run.sh) can only approximate.
#
# Under a dry-run no files are persisted (config, .done markers, secrets are
# all log-only), so the test asserts on the captured output instead:
#   * cmd_install exits 0 (no die/exit crashed the pipeline)
#   * each expected phase emitted its "[dry-run] phase mark <id>" line,
#     proving the phase actually ran rather than being skipped.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export APP_ROOT="$ROOT"
    TMP="$(mktemp -d)"
    export APP_LOG_DIR="$TMP" LOG_FILE="$TMP/log"
    export DRY_RUN=1 ASSUME_YES=1 OFFLINE=1 MAILSTEAD_ALLOW_NO_SYSTEMD=1
    # brand.sh pins APP_* to the real system paths; re-point them at the
    # scratch dir AFTER sourcing base but BEFORE os_init copies them to *_DIR.
    _source_base
    export APP_ETC="$TMP/etc" APP_LIB="$TMP/lib" APP_BACKUP="$TMP/bak" \
        APP_OPT="$TMP/opt" APP_LIBEXEC="$TMP/libexec" APP_LOG="$TMP/logd"
    os_init
    _source_modules
    # This is a flow/preview test, not a root-gate test: neutralize the root
    # check so the pipeline runs to completion as the current (non-root) user.
    require_root() { :; }
}

teardown() { rm -rf "$TMP"; }

_source_base() {
    # shellcheck source=/dev/null
    source "$APP_ROOT/lib/brand.sh"
    # shellcheck source=/dev/null
    source "$APP_ROOT/lib/common.sh"
    # shellcheck source=/dev/null
    source "$APP_ROOT/lib/os.sh"
}

_source_modules() {
    local m
    for m in config components db tls nginx postfix dovecot dkim rspamd \
        postfixadmin roundcube dnsrecords security backup report autoconfig \
        signatures preflight cli install; do
        # shellcheck source=/dev/null
        source "${APP_ROOT}/lib/${m}.sh"
    done
}

# Run cmd_install capturing all output; set RC and OUT.
_run_install() {
    local out
    out="$(cmd_install "$@" 2>&1)"
    RC=$?
    OUT="$out"
}

# Assert a specific phase actually ran (emitted its dry-run mark).
_phase_ran() {
    local id="$1"
    grep -qE "^\[dry-run\] phase mark ${id}$" <<<"$OUT" \
        || { echo "expected phase ${id} to run; not found in output:"; grep -E "dry-run\] phase mark|skip\] ${id}" <<<"$OUT"; return 1; }
}

# Core phases every preset must run.
_CORE=(P00 P01 P03 P04 P05 P06 P07 P08 P12 P13 P15 P16)

@test "cmd_install (minimal, selfsigned, dry-run) completes P00-P16" {
    _run_install --preset minimal --domain example.test \
        --admin-email admin@example.test --ip4 127.0.0.1 --tls selfsigned
    [ "$RC" -eq 0 ] || { echo "cmd_install failed (rc=${RC}):\n${OUT}"; return 1; }
    local id
    for id in "${_CORE[@]}"; do _phase_ran "$id"; done
}

@test "cmd_install (standard, dry-run) runs webmail + signatures + autoconfig" {
    _run_install --preset standard --domain example.test \
        --admin-email admin@example.test --ip4 127.0.0.1 --tls selfsigned
    [ "$RC" -eq 0 ] || { echo "cmd_install failed (rc=${RC}):\n${OUT}"; return 1; }
    local id
    for id in P10 P10b P11b; do _phase_ran "$id"; done
}
