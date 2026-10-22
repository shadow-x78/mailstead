#!/usr/bin/env bats
# ─────────────────────────────────────────────
# Mailstead - Postfix Configuration Tests
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export APP_ROOT="$ROOT"
    TMP="$(mktemp -d)"
    export APP_LOG_DIR="$TMP"
    export LOG_FILE="$TMP/mailstead.log"
    if declare -f run >/dev/null 2>&1; then _BATS_RUN="$(declare -f run)"; fi
    # shellcheck source=/dev/null
    source "$ROOT/lib/brand.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    if [[ -n "${_BATS_RUN:-}" ]]; then eval "$_BATS_RUN"; fi
    # shellcheck source=/dev/null
    source "$ROOT/lib/postfix.sh"
    DRY_RUN=1
    ASSUME_YES=1
}

teardown() { rm -rf "$TMP"; }

@test "Postfix >= 3.6 uses compatibility_level 3.6 and range operator" {
    postconf() { printf '3.7.11\n'; }
    postfix_compat_vars
    [ "$POSTFIX_COMPAT_LEVEL" = "3.6" ]
    [ "$POSTFIX_TLS_PROTOCOLS" = ">=TLSv1.2" ]
}

@test "Postfix 3.5 (RHEL/Alma 9) avoids 3.6-only syntax" {
    postconf() { printf '3.5.9\n'; }
    postfix_compat_vars
    [ "$POSTFIX_COMPAT_LEVEL" = "2" ]
    [[ "$POSTFIX_TLS_PROTOCOLS" != *">="* ]]
    [[ "$POSTFIX_TLS_PROTOCOLS" == *"TLSv1.2"* ]]
}

@test "unknown Postfix version falls back to the safe legacy syntax" {
    postconf() { return 1; }
    postfix_compat_vars
    [ "$POSTFIX_COMPAT_LEVEL" = "2" ]
    [[ "$POSTFIX_TLS_PROTOCOLS" != *">="* ]]
}

@test "main.cf template renders version-appropriate TLS settings" {
    DRY_RUN=0
    local src dst
    src="$ROOT/templates/postfix/main.cf.tpl"
    dst="$TMP/main.cf"
    MAIL_HOSTNAME="mail.example.com"
    PRIMARY_DOMAIN="example.com"
    INET_PROTOCOLS="ipv4"
    SMTP_TLS_LEVEL="may"
    TLS_CERT_FILE="/etc/ssl/x.pem"
    TLS_KEY_FILE="/etc/ssl/x.key"
    POSTFIX_MAPS_BLOCK="# maps"
    POSTFIX_MILTERS_BLOCK="# milters"
    POSTFIX_COMPAT_LEVEL="3.6"
    POSTFIX_TLS_PROTOCOLS=">=TLSv1.2"
    TPL_VARS="MAIL_HOSTNAME PRIMARY_DOMAIN INET_PROTOCOLS SMTP_TLS_LEVEL TLS_CERT_FILE TLS_KEY_FILE POSTFIX_MAPS_BLOCK POSTFIX_MILTERS_BLOCK POSTFIX_COMPAT_LEVEL POSTFIX_TLS_PROTOCOLS"
    run render_template "$src" "$dst" 0644 "$(id -un):$(id -gn)"
    [ "$status" -eq 0 ]
    run grep -F 'compatibility_level = 3.6' "$dst"
    [ "$status" -eq 0 ]
    run grep -F 'smtpd_tls_protocols = >=TLSv1.2' "$dst"
    [ "$status" -eq 0 ]
    ! grep -q '@@' "$dst"
}
