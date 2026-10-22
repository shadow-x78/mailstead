#!/usr/bin/env bats
# tests/dkim.bats - OpenDKIM record parsing and table domain matching.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export APP_ROOT="$ROOT"
    TMP="$(mktemp -d)"
    export APP_LOG_DIR="$TMP"
    export LOG_FILE="$TMP/mailstead.log"
    # lib/common.sh defines run(); preserve bats' run so it can capture status.
    if declare -f run >/dev/null 2>&1; then _BATS_RUN="$(declare -f run)"; fi
    # shellcheck source=/dev/null
    source "$ROOT/lib/brand.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    if [[ -n "${_BATS_RUN:-}" ]]; then eval "$_BATS_RUN"; fi
    # shellcheck source=/dev/null
    source "$ROOT/lib/dkim.sh"
    APP_LIB="$TMP/lib"
    APP_ETC="$TMP/etc"
    export APP_LIB APP_ETC
    mkdir -p "$TMP/opendkim/keys"
    # Point the conf dir at the test scratch space.
    opendkim_conf_dir() { printf '%s/opendkim' "$TMP"; }
    dkim_key_dir() { printf '%s/opendkim/keys/%s' "$TMP" "$1"; }
    DRY_RUN=0
    ASSUME_YES=1
}

teardown() { rm -rf "$TMP"; }

@test "dkim_record_string joins quoted chunks without truncating at semicolons" {
    mkdir -p "$TMP/opendkim/keys/example.com"
    cat >"$TMP/opendkim/keys/example.com/mail202601.txt" <<'EOF'
mail202601._domainkey	IN	TXT	( "v=DKIM1; h=sha256; k=rsa; "
	  "p=ABCDEF123456" )  ; ----- DKIM key mail202601 for example.com
EOF
    run dkim_record_string example.com mail202601
    [ "$status" -eq 0 ]
    [ "$output" = "v=DKIM1; h=sha256; k=rsa; p=ABCDEF123456" ]
}

@test "dkim_record_string does not include the trailing comment" {
    mkdir -p "$TMP/opendkim/keys/example.com"
    printf 'x\tIN\tTXT\t( "v=DKIM1; " "p=KEY" )  ; comment\n' >"$TMP/opendkim/keys/example.com/x.txt"
    run dkim_record_string example.com x
    [ "$output" = "v=DKIM1; p=KEY" ]
}

@test "table domain removal never matches a subdomain" {
    cat >"$TMP/k.tbl" <<'EOF'
a._domainkey.example.com example.com:a:/p
*@example.com a._domainkey.example.com
b._domainkey.sub.example.com sub.example.com:b:/p2
EOF
    _dkim_table_remove_domain "$TMP/k.tbl" example.com
    run grep -c 'example.com' "$TMP/k.tbl"
    # Only the sub.example.com line remains.
    [ "$output" = "1" ]
    run grep -F 'sub.example.com' "$TMP/k.tbl"
    [ "$status" -eq 0 ]
}

@test "table upsert replaces the previous selector for a domain" {
    printf 'old._domainkey.example.com example.com:old:/p\n' >"$TMP/k.tbl"
    _dkim_table_upsert "$TMP/k.tbl" example.com "new._domainkey.example.com example.com:new:/p"
    run grep -c 'example.com' "$TMP/k.tbl"
    [ "$output" = "1" ]
    run grep -F 'new._domainkey.example.com' "$TMP/k.tbl"
    [ "$status" -eq 0 ]
    ! grep -q 'old._domainkey' "$TMP/k.tbl"
}