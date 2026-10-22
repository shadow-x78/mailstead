#!/usr/bin/env bats
# tests/signatures.bats - tests for scripts/mailstead-sig.py.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    SIG="$ROOT/scripts/mailstead-sig.py"
    TMP="$(mktemp -d)"
}

teardown() { rm -rf "$TMP"; }

@test "sanitize allows tables and links" {
    printf '<table><tr><td><a href="https://example.com">x</a></td></tr></table>' >"$TMP/in.html"
    run python3 "$SIG" sanitize "$TMP/in.html"
    [ "$status" -eq 0 ]
    [[ "$output" == *"<table>"* ]]
    [[ "$output" == *"https://example.com"* ]]
}

@test "sanitize strips script tags" {
    printf '<div>ok</div><script>alert(1)</script>' >"$TMP/in.html"
    run python3 "$SIG" sanitize "$TMP/in.html"
    [ "$status" -eq 0 ]
    [[ "$output" != *"<script"* ]]
}

@test "sanitize rejects data: images" {
    printf '<img src="data:image/png;base64,AAAA">' >"$TMP/in.html"
    run python3 "$SIG" sanitize "$TMP/in.html"
    [ "$status" -eq 2 ]
}

@test "sanitize rejects javascript: href" {
    printf '<a href="javascript:alert(1)">x</a>' >"$TMP/in.html"
    run python3 "$SIG" sanitize "$TMP/in.html"
    [ "$status" -eq 0 ]
    [[ "$output" != *"javascript:"* ]]
}

@test "render substitutes and escapes values" {
    printf 'Hi {{NAME}} {{#TITLE}}[{{TITLE}}]{{/TITLE}}' >"$TMP/t.tpl"
    run python3 "$SIG" render "$TMP/t.tpl" --set 'NAME=<b>x</b>' --set 'TITLE='
    [ "$status" -eq 0 ]
    [[ "$output" == *"&lt;b&gt;x&lt;/b&gt;"* ]]
    [[ "$output" != *"[["* ]]
}

@test "render includes conditional section when set" {
    printf 'Hi {{#TITLE}}[{{TITLE}}]{{/TITLE}}' >"$TMP/t.tpl"
    run python3 "$SIG" render "$TMP/t.tpl" --set 'TITLE=CEO'
    [ "$status" -eq 0 ]
    [ "$output" = "Hi [CEO]" ]
}

@test "totext turns links into parentheses" {
    printf '<p>See <a href="https://e.com">site</a></p>' >"$TMP/in.html"
    run python3 "$SIG" totext "$TMP/in.html"
    [ "$status" -eq 0 ]
    [[ "$output" == *"site (https://e.com)"* ]]
}

@test "inspect-image reads a valid PNG" {
    python3 - "$TMP/logo.png" <<'PY'
import struct, sys, zlib
def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
ihdr = struct.pack(">IIBBBBB", 100, 50, 8, 2, 0, 0, 0)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
PY
    run python3 "$SIG" inspect-image "$TMP/logo.png"
    [ "$status" -eq 0 ]
    [ "$output" = "100x50 png" ]
}

@test "inspect-image rejects SVG" {
    printf '<svg xmlns="http://www.w3.org/2000/svg"></svg>' >"$TMP/x.svg"
    run python3 "$SIG" inspect-image "$TMP/x.svg"
    [ "$status" -eq 2 ]
}

@test "inspect-image rejects oversized logo dimensions" {
    python3 - "$TMP/big.png" <<'PY'
import struct, sys, zlib
def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
ihdr = struct.pack(">IIBBBBB", 900, 300, 8, 2, 0, 0, 0)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
PY
    run python3 "$SIG" inspect-image "$TMP/big.png" logo
    [ "$status" -eq 2 ]
}

@test "deployed footer template renders to valid python" {
    local tpl content
    tpl="$ROOT/templates/signatures/mailstead-footer.py.tpl"
    [ -r "$tpl" ]
    content="$(cat -- "$tpl")"
    content="${content//@@APP_LIB@@//var/lib/mailstead}"
    [[ "$content" != *'@@'* ]]
    printf '%s' "$content" >"$TMP/footer.py"
    run python3 -m py_compile "$TMP/footer.py"
    [ "$status" -eq 0 ]
    run grep -F 'LIB_DIR = "/var/lib/mailstead"' "$TMP/footer.py"
    [ "$status" -eq 0 ]
}