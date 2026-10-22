#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Credit Banner Guard
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

# Verifies that every shipped source file opens with the standard credit
# banner, so the convention cannot drift as the tree grows.
#
# Two banner shapes are accepted:
#
#   Block style - shell, python, yaml, env, sql, php, and the config files:
#     <prefix> ─────────────────────────────────────────────
#     <prefix> Mailstead - <Purpose>
#     <prefix> https://github.com/shadow-x78/mailstead
#     <prefix> ─────────────────────────────────────────────
#     <blank>
#
#   XML style - xml and html documents, which must keep their declaration
#   first:
#     <?xml ...?>
#     <!-- Mailstead - <Purpose> https://github.com/shadow-x78/mailstead -->
#     <blank>
#
# ── Exit Codes ──
# 0: every file conforms, 1: violations found

set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
status=0

rule='─────────────────────────────────────────────'
url='https://github.com/shadow-x78/mailstead'

# ── File Discovery ──
collect_files() {
    find "$root" -type f \( -name '*.sh' -o -name '*.bats' -o -name '*.py' \) \
        ! -path '*/.git/*' -print
    find "$root/templates" -type f \( -name '*.tpl' -o -name '*.sql' -o -name '*.php' \) \
        ! -name 'text-only.txt.tpl' -print
    find "$root/config" -type f -name '*.env' -print
    find "$root/.github/workflows" -type f -name '*.yml' -print
    find "$root/.github/ISSUE_TEMPLATE" -type f -name '*.yml' -print
    printf '%s\n' "$root/mailstead" "$root/install.sh"
    printf "%s\n" "$root/.editorconfig" "$root/.shellcheckrc" "$root/.gitignore" "$root/.gitattributes"
}

# ── Block Style Check ──
check_block() {
    local file="$1"
    local offset=0
    local first
    first="$(head -n 1 "$file" 2>/dev/null || true)"
    case "$first" in
        '#!'*) offset=1 ;;
        '<?php'*) offset=1 ;;
    esac

    local n=$((offset + 1))
    local l1 l2 l3 l4 l5
    l1="$(sed -n "${n}p" "$file")"
    l2="$(sed -n "$((n + 1))p" "$file")"
    l3="$(sed -n "$((n + 2))p" "$file")"
    l4="$(sed -n "$((n + 3))p" "$file")"
    l5="$(sed -n "$((n + 4))p" "$file")"

    local ok=1
    case "$l1" in
        "# $rule" | "; $rule" | "-- $rule" | "// $rule") ;;
        *) ok=0 ;;
    esac
    case "$l2" in
        '# Mailstead - '* | '; Mailstead - '* | '-- Mailstead - '* | '// Mailstead - '*) ;;
        *) ok=0 ;;
    esac
    case "$l3" in
        "# $url" | "; $url" | "-- $url" | "// $url") ;;
        *) ok=0 ;;
    esac
    case "$l4" in
        "# $rule" | "; $rule" | "-- $rule" | "// $rule") ;;
        *) ok=0 ;;
    esac
    [ -z "$l5" ] || ok=0

    [ "$ok" -eq 1 ] || {
        echo "::error file=${file#"$root"/}::missing or malformed credit banner"
        status=1
    }
}

# ── XML Style Check ──
check_xml() {
    local file="$1"
    local line
    local found=0

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            '<?xml'*) continue ;;
            '<!DOCTYPE'*) continue ;;
            '') continue ;;
            '<!-- Mailstead - '*) found=1 ;;
            *) break ;;
        esac
    done <"$file"

    if [ "$found" -eq 0 ]; then
        echo "::error file=${file#"$root"/}::missing or malformed credit banner"
        status=1
    fi
}

# ── Dispatch ──
while IFS= read -r file; do
    [ -f "$file" ] || continue
    case "$file" in
        *.xml.tpl | *.html.tpl | */mobileconfig.tpl)
            check_xml "$file"
            ;;
        *)
            check_block "$file"
            ;;
    esac
done < <(collect_files)

if [ "$status" -eq 0 ]; then
    echo "credit banner policy holds"
fi
exit "$status"
