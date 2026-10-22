#!/usr/bin/env bats
# tests/common.bats - unit tests for lib/common.sh helpers.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export APP_ROOT="$ROOT"
    TMP="$(mktemp -d)"
    export APP_LOG_DIR="$TMP"
    export LOG_FILE="$TMP/mailstead.log"
    export APP_ETC="$TMP/etc"
    # lib/common.sh defines run(); preserve bats' run so it can capture status.
    if declare -f run >/dev/null 2>&1; then _BATS_RUN="$(declare -f run)"; fi
    # shellcheck source=/dev/null
    source "$ROOT/lib/brand.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    if [[ -n "${_BATS_RUN:-}" ]]; then eval "$_BATS_RUN"; fi
    OWN="$(id -un):$(id -gn)"
    DRY_RUN=0
    ASSUME_YES=1
}

teardown() { rm -rf "$TMP"; }

@test "validate_domain accepts normal domains" {
    run validate_domain example.com
    [ "$status" -eq 0 ]
    run validate_domain mail.example.co.uk
    [ "$status" -eq 0 ]
}

@test "validate_domain rejects bad domains" {
    run validate_domain "not a domain"
    [ "$status" -ne 0 ]
    run validate_domain "-bad.com"
    [ "$status" -ne 0 ]
    run validate_domain "example"
    [ "$status" -ne 0 ]
}

@test "validate_email accepts and rejects" {
    run validate_email user.name+tag@example.com
    [ "$status" -eq 0 ]
    run validate_email "user@@example.com"
    [ "$status" -ne 0 ]
    run validate_email "user@bad"
    [ "$status" -ne 0 ]
}

@test "gen_password is alnum and correct length" {
    local p
    p="$(gen_password 24)"
    [ "${#p}" -eq 24 ]
    [[ "$p" =~ ^[A-Za-z0-9]+$ ]]
}

@test "xml_escape escapes special characters" {
    run xml_escape '<a & "b">'
    [ "$output" = '&lt;a &amp; &quot;b&quot;&gt;' ]
}

@test "render_template substitutes TPL_VARS" {
    local dir src dst
    dir="$(mktemp -d)"
    src="${dir}/in.tpl"
    dst="${dir}/out.conf"
    printf 'host = @@MAIL_HOSTNAME@@\nport = 587\n' >"$src"
    MAIL_HOSTNAME="mail.example.com"
    TPL_VARS="MAIL_HOSTNAME"
    run render_template "$src" "$dst" 0644 "$OWN"
    [ "$status" -eq 0 ]
    run cat "$dst"
    [ "$output" = "$(printf 'host = mail.example.com\nport = 587')" ]
    rm -rf "$dir"
}

@test "render_template fails on unresolved placeholder" {
    local dir src dst
    dir="$(mktemp -d)"
    src="${dir}/in.tpl"
    dst="${dir}/out.conf"
    printf 'x = @@MISSING_VAR@@\n' >"$src"
    TPL_VARS=""
    run render_template "$src" "$dst"
    [ "$status" -ne 0 ]
    rm -rf "$dir"
}

@test "render_template preserves literal dollar signs" {
    local dir src dst
    dir="$(mktemp -d)"
    src="${dir}/in.tpl"
    dst="${dir}/out.conf"
    printf 'myhostname = @@H@@\nmydestination = $myhostname, localhost\n' >"$src"
    H="mail.example.com"
    TPL_VARS="H"
    render_template "$src" "$dst" 0644 "$OWN"
    run grep -F '$myhostname' "$dst"
    [ "$status" -eq 0 ]
    rm -rf "$dir"
}

# Bash 5.3 treats "&" in a ${var//pat/rep} replacement as the matched text;
# render_template must substitute values containing "&" literally.
@test "render_template keeps ampersands in values" {
    local dir src dst
    dir="$(mktemp -d)"
    src="${dir}/in.tpl"
    dst="${dir}/out.conf"
    printf 'name = @@N@@\nurl = @@U@@\n' >"$src"
    N="R&D"
    U="https://example.com/?a=1&b=2"
    TPL_VARS="N U"
    run render_template "$src" "$dst" 0644 "$OWN"
    [ "$status" -eq 0 ]
    run cat "$dst"
    [ "$output" = "$(printf 'name = R&D\nurl = https://example.com/?a=1&b=2')" ]
    rm -rf "$dir"
}

@test "xml_escape leaves ampersand entities correct on Bash 5.3" {
    run xml_escape 'A&B<C>"D"'
    [ "$output" = 'A&amp;B&lt;C&gt;&quot;D&quot;' ]
}

# Regression: the dispatcher sets IFS=$'\n\t', under which an unquoted
# space-separated TPL_VARS would NOT word-split. render_template must still
# substitute every variable.
@test "render_template splits space-separated TPL_VARS under dispatcher IFS" {
    local dir src dst
    dir="$(mktemp -d)"
    src="${dir}/in.tpl"
    dst="${dir}/out.conf"
    printf 'h=@@A@@ d=@@B@@ c=@@C@@\n' >"$src"
    run bash -c '
        set -Eeuo pipefail
        IFS=$'"'"'\n\t'"'"'
        APP_ROOT="$1"; LOG_FILE="$2"; DRY_RUN=0
        . "$APP_ROOT/lib/brand.sh"
        . "$APP_ROOT/lib/common.sh"
        A=one; B=two; C=three; TPL_VARS="A B C"
        render_template "$3" "$4" 0644 "$(id -un):$(id -gn)"
        cat "$4"
    ' _ "$ROOT" "$TMP/mailstead.log" "$src" "$dst"
    [ "$status" -eq 0 ]
    [[ "$output" == *"h=one d=two c=three"* ]]
    rm -rf "$dir"
}