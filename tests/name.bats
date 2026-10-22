#!/usr/bin/env bats
# ─────────────────────────────────────────────
# Mailstead - Project Name Guard Tests
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

# Plan-3 section B/H6. The plan markdown files themselves are the spec and are
# excluded, as are the tests that mention the rejected names on purpose.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "no rejected names in shipped source" {
    run grep -rIEn 'mailforge|mailwright|sealpost' \
        "$ROOT/mailstead" \
        "$ROOT/install.sh" \
        "$ROOT/lib" \
        "$ROOT/phases" \
        "$ROOT/templates" \
        "$ROOT/config" \
        "$ROOT/scripts"
    # grep exits 1 when nothing matches.
    [ "$status" -eq 1 ]
}

@test "the brand file is the single source of the project name" {
    run grep -F 'APP_SLUG="mailstead"' "$ROOT/lib/brand.sh"
    [ "$status" -eq 0 ]
}
