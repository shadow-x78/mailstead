#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Terminal Banner
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

[ -n "${_MS_BANNER_LOADED:-}" ] && return 0
_MS_BANNER_LOADED=1

# ── Colour Support ──
MS_COLOR_SUPPORT=0
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${MS_NO_256:-}" ]; then
    _ms_colors=$(tput colors 2>/dev/null || echo 0)
    if [ "$_ms_colors" -ge 256 ] 2>/dev/null; then
        MS_COLOR_SUPPORT=256
    elif [ "$_ms_colors" -ge 16 ] 2>/dev/null; then
        MS_COLOR_SUPPORT=16
    fi
fi

if [ "$MS_COLOR_SUPPORT" -eq 256 ] 2>/dev/null; then
    MS_COLOR_PRIMARY='\033[38;5;208m'
    MS_COLOR_ACCENT='\033[38;5;39m'
    MS_COLOR_MUTED='\033[38;5;245m'
elif [ "$MS_COLOR_SUPPORT" -eq 16 ] 2>/dev/null; then
    MS_COLOR_PRIMARY='\033[0;33m'
    MS_COLOR_ACCENT='\033[1;36m'
    MS_COLOR_MUTED='\033[0;37m'
else
    MS_COLOR_PRIMARY=''
    MS_COLOR_ACCENT=''
    MS_COLOR_MUTED=''
fi

MS_NC='\033[0m'
if [ "$MS_COLOR_SUPPORT" -eq 0 ] 2>/dev/null; then
    MS_NC=''
fi

# ── Glyph Support ──
MS_GLYPH_SUPPORT=0
if [ -z "${MS_ASCII:-}" ]; then
    case "${LANG:-}${LC_ALL:-}${LC_CTYPE:-}" in
        *UTF-8* | *utf8*) [ -t 1 ] && MS_GLYPH_SUPPORT=1 ;;
    esac
    if [ "$MS_GLYPH_SUPPORT" -eq 0 ] 2>/dev/null && command -v locale >/dev/null 2>&1; then
        _ms_charmap=$(locale charmap 2>/dev/null || true)
        case "$_ms_charmap" in
            UTF-8* | utf-8*) [ -t 1 ] && MS_GLYPH_SUPPORT=1 ;;
        esac
    fi
fi

# ── Logo: Envelope ──
_ms_logo_glyph=(
    '   ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄   '
    '  █████████████████████  '
    ' ███████████████████████ '
    ' ██▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀██ '
    ' ██ ▀▄▄           ▄▄▀ ██ '
    ' ██     ▀▄▄   ▄▄▀     ██ '
    ' ██       ▀▀▀▀▀       ██ '
    ' ██                   ██ '
    ' ██                   ██ '
    ' ██                   ██ '
    ' ███████████████████████ '
    '   ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀   '
)

_ms_logo_ascii=(
    '   -------------------   '
    '  #####################  '
    ' ####################### '
    ' ##-------------------## '
    ' ## --\           /-- ## '
    ' ##     --\   /--     ## '
    ' ##       -----       ## '
    ' ##                   ## '
    ' ##                   ## '
    ' ##                   ## '
    ' ####################### '
    '   -------------------   '
)

# ── Wordmark: MAIL ──
_ms_word_glyph=(
    '███╗   ███╗ █████╗ ██╗██╗     '
    '████╗ ████║██╔══██╗██║██║     '
    '██╔████╔██║███████║██║██║     '
    '██║╚██╔╝██║██╔══██║██║██║     '
    '██║ ╚═╝ ██║██║  ██║██║███████╗'
    '╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚══════╝'
)

_ms_word_ascii=(
    '#    #  ####   ####  ##       '
    '##  ## ##  ##   ##   ##       '
    '# ## # ##  ##   ##   ##       '
    '#    # ######   ##   ##       '
    '#    # ##  ##   ##   ##       '
    '#    # ##  ##  ####  ######   '
)

# ── Terminal Columns ──
_ms_term_cols() {
    if [ -z "${MS_TERM_COLS:-}" ]; then
        MS_TERM_COLS=$(tput cols 2>/dev/null || echo 80)
        [ -z "$MS_TERM_COLS" ] && MS_TERM_COLS=80
    fi
    printf '%s' "$MS_TERM_COLS"
}

# ── Banner ──
mailstead_banner() {
    local _ms_cols="${1:-$(_ms_term_cols)}"
    _ms_cols="${_ms_cols:-80}"
    case "$_ms_cols" in
        '' | *[!0-9]*) _ms_cols=80 ;;
    esac

    local -a _ms_logo=()
    local -a _ms_word=()
    local _ms_sep='│'
    if [ "${MS_GLYPH_SUPPORT:-0}" -eq 1 ] 2>/dev/null; then
        _ms_logo=("${_ms_logo_glyph[@]}")
        _ms_word=("${_ms_word_glyph[@]}")
    else
        _ms_logo=("${_ms_logo_ascii[@]}")
        _ms_word=("${_ms_word_ascii[@]}")
        _ms_sep='|'
    fi

    local _ms_word_top=3
    local _ms_word_w=${#_ms_word[0]}
    local _ms_width=$((${#_ms_logo[0]} + 3 + _ms_word_w))
    local _ms_pad=$(((_ms_cols - _ms_width) / 2))
    [ "$_ms_pad" -lt 0 ] && _ms_pad=0

    local _ms_i
    local _ms_blank
    _ms_blank=$(printf '%*s' "$_ms_word_w" '')

    for _ms_i in "${!_ms_logo[@]}"; do
        local _ms_right="$_ms_blank"
        local _ms_off=$((_ms_i - _ms_word_top))
        if [ "$_ms_off" -ge 0 ] && [ "$_ms_off" -lt "${#_ms_word[@]}" ]; then
            _ms_right="${_ms_word[$_ms_off]}"
        fi
        printf '%b%*s%s %s %s%b\n' \
            "$MS_COLOR_PRIMARY" "$_ms_pad" '' \
            "${_ms_logo[$_ms_i]}" "$_ms_sep" "$_ms_right" "$MS_NC"
    done
    printf '\n'

    local _ms_tag
    if [ "${MS_GLYPH_SUPPORT:-0}" -eq 1 ] 2>/dev/null; then
        _ms_tag="Mailstead · v${APP_VERSION:-unknown} · Build and manage a self-hosted mail server."
    else
        _ms_tag="Mailstead - v${APP_VERSION:-unknown} - Build and manage a self-hosted mail server."
    fi
    local _ms_taglen
    _ms_taglen=$(printf '%s' "$_ms_tag" | wc -m | tr -d ' ')
    local _ms_tpad=$(((_ms_cols - _ms_taglen) / 2))
    [ "$_ms_tpad" -lt 0 ] && _ms_tpad=0
    printf '%b%*s%s%b\n' "$MS_COLOR_ACCENT" "$_ms_tpad" '' "$_ms_tag" "$MS_NC"

    local _ms_auth='By shadow-x78'
    local _ms_authlen
    _ms_authlen=$(printf '%s' "$_ms_auth" | wc -m | tr -d ' ')
    local _ms_apad=$(((_ms_cols - _ms_authlen) / 2))
    [ "$_ms_apad" -lt 0 ] && _ms_apad=0
    printf '%b%*s%s%b\n\n' "$MS_COLOR_MUTED" "$_ms_apad" '' "$_ms_auth" "$MS_NC"
}
