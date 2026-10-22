#!/usr/bin/env bash
# lib/banner.sh — Mailstead banner (ASCII art + ANSI colors).
#
# Usage:
#   source lib/banner.sh
#   mailstead_banner            # full banner with colors
#   mailstead_banner --ascii    # force ASCII (no glyphs)

[ -n "${_MS_BANNER_LOADED:-}" ] && return 0
_MS_BANNER_LOADED=1

# ── color support detection ────────────────────────────────────────
MS_COLOR_SUPPORT=0
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${MS_NO_256:-}" ]; then
    _ms_cols=$(tput colors 2>/dev/null || echo 0)
    if [ "$_ms_cols" -ge 256 ] 2>/dev/null; then
        MS_COLOR_SUPPORT=256
    elif [ "$_ms_cols" -ge 16 ] 2>/dev/null; then
        MS_COLOR_SUPPORT=16
    fi
fi

# ── color definitions ─────────────────────────────────────────────
if [ "$MS_COLOR_SUPPORT" -eq 256 ] 2>/dev/null; then
    MS_COLOR_PRIMARY='\033[38;5;208m'   # orange
    MS_COLOR_ACCENT='\033[38;5;39m'     # teal
    MS_COLOR_MUTED='\033[38;5;245m'     # gray
elif [ "$MS_COLOR_SUPPORT" -eq 16 ] 2>/dev/null; then
    MS_COLOR_PRIMARY='\033[1;33m'       # bold yellow
    MS_COLOR_ACCENT='\033[1;36m'        # bold cyan
    MS_COLOR_MUTED='\033[1;37m'         # bold white
else
    MS_COLOR_PRIMARY=''
    MS_COLOR_ACCENT=''
    MS_COLOR_MUTED=''
fi

MS_NC='\033[0m'

# ── glyph detection ────────────────────────────────────────────────
MS_GLYPH_SUPPORT=0
case "${LANG:-}${LC_ALL:-}${LC_CTYPE:-}" in
    *UTF-8*|*utf8*) [ -t 1 ] && MS_GLYPH_SUPPORT=1 ;;
esac
if [ "$MS_GLYPH_SUPPORT" -eq 0 ] 2>/dev/null && command -v locale >/dev/null 2>&1; then
    _ms_charmap=$(locale charmap 2>/dev/null || true)
    case "$_ms_charmap" in
        UTF-8*|utf-8*) [ -t 1 ] && MS_GLYPH_SUPPORT=1 ;;
    esac
fi

# Force ASCII mode
[ -n "${MS_ASCII:-}" ] && MS_GLYPH_SUPPORT=0

# ── logo lines (filled blocks only — no box-drawing chars) ──────────
#
# Design: solid mailbox with MAIL text and a flag sticking to the right.
# Uses only █▀▄ (full-width block chars) — renders identically in all
# terminals regardless of font or box-drawing support.
#
if [ "$MS_GLYPH_SUPPORT" -eq 1 ]; then
    _ms_l1='    ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀'
    _ms_l2='    █████████████████████'
    _ms_l3='    ██        MAIL      ██'
    _ms_l4='    ██                  ██'
    _ms_l5='    ██                  ██'
    _ms_l6='    █████████████████████'
    _ms_l7='    ██                  ██'
    _ms_l8='    ██                  ██'
    _ms_l9='    ██                  ██'
    _ms_l10='    █████████████████████'
    _ms_l11='    ██   ████  ██  ██'
    _ms_l12='    ██   ██      ██'
    _ms_l13='    ██   ██      ██'
    _ms_l14='    ██   ████  ██  ██'
    _ms_l15='    ██                  ██'
    _ms_l16='    ██                  ██'
    _ms_l17='    ▀▀▀▀▀▀▀     ██  ▀▀▀▀▀▀▀'
else
    _ms_l1='    +++++++++++++++++++++++'
    _ms_l2='    +++++++++++++++++++++++'
    _ms_l3='    +        MAIL      +'
    _ms_l4='    +                  +'
    _ms_l5='    +                  +'
    _ms_l6='    +++++++++++++++++++++++'
    _ms_l7='    +                  +'
    _ms_l8='    +                  +'
    _ms_l9='    +                  +'
    _ms_l10='    +++++++++++++++++++++++'
    _ms_l11='    +   ++++  +  +'
    _ms_l12='    +   ++      +'
    _ms_l13='    +   ++      +'
    _ms_l14='    +   ++++  +  +'
    _ms_l15='    +                  +'
    _ms_l16='    +                  +'
    _ms_l17='    ++++      ++    ++++'
fi

# ── terminal column count ──────────────────────────────────────────
_ms_term_cols() {
    if [ -z "${MS_TERM_COLS:-}" ]; then
        MS_TERM_COLS=$(tput cols 2>/dev/null || echo 80)
        [ -z "$MS_TERM_COLS" ] && MS_TERM_COLS=80
    fi
    printf '%s' "$MS_TERM_COLS"
}

# ── full banner ───────────────────────────────────────────────────
mailstead_banner() {
    local _ms_cols="${1:-$(ms_term_cols)}"
    _ms_cols="${_ms_cols:-80}"

    # Find the widest logo line
    local _ms_max=0
    local _ms_L
    for _ms_L in "$_ms_l1" "$_ms_l2" "$_ms_l3" "$_ms_l4" "$_ms_l5" "$_ms_l6" "$_ms_l7" "$_ms_l8" "$_ms_l9" "$_ms_l10" "$_ms_l11" "$_ms_l12" "$_ms_l13" "$_ms_l14" "$_ms_l15" "$_ms_l16" "$_ms_l17"; do
        local _ms_w=${#_ms_L}
        [ "$_ms_w" -gt "$_ms_max" ] && _ms_max=$_ms_w
    done

    # Pad each line
    local _ms_pad=$(( (_ms_cols - _ms_max) / 2 ))
    [ "$_ms_pad" -lt 0 ] && _ms_pad=0

    for _ms_L in "$_ms_l1" "$_ms_l2" "$_ms_l3" "$_ms_l4" "$_ms_l5" "$_ms_l6" "$_ms_l7" "$_ms_l8" "$_ms_l9" "$_ms_l10" "$_ms_l11" "$_ms_l12" "$_ms_l13" "$_ms_l14" "$_ms_l15" "$_ms_l16" "$_ms_l17"; do
        printf "${MS_COLOR_PRIMARY}%*s${_ms_L}${MS_NC}\n" "$_ms_pad" ''
    done
    printf '\n'

    # Tag line
    local _ms_tag="Mailstead · v${APP_VERSION:-0.1.0} · Build and manage a self-hosted mail server."
    local _ms_taglen
    _ms_taglen=$(printf '%s' "$_ms_tag" | wc -m | tr -d ' ')
    local _ms_tpad=$(( (_ms_cols - _ms_taglen) / 2 ))
    [ "$_ms_tpad" -lt 0 ] && _ms_tpad=0
    printf "${MS_COLOR_ACCENT}%*s${_ms_tag}${MS_NC}\n" "$_ms_tpad" ''

    # Author line
    local _ms_auth="By shadow-x78"
    local _ms_authlen
    _ms_authlen=$(printf '%s' "$_ms_auth" | wc -m | tr -d ' ')
    local _ms_apad=$(( (_ms_cols - _ms_authlen) / 2 ))
    [ "$_ms_apad" -lt 0 ] && _ms_apad=0
    printf "${MS_COLOR_MUTED}%*s${_ms_auth}${MS_NC}\n\n" "$_ms_apad" ''
}

# ── shorthand ─────────────────────────────────────────────────────
ms_term_cols() { _ms_term_cols; }
