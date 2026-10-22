#!/usr/bin/env bash
# lib/common.sh - logging, error handling, validators, template rendering,
# backups, state and phase bookkeeping. Required by every other module.
#
# Every function respects the global flags set by the dispatcher:
#   DRY_RUN=1   -> print actions instead of executing them
#   ASSUME_YES=1 -> confirm() answers yes without prompting
#   VERBOSE=1   -> extra diagnostics

# shellcheck shell=bash

# ---- globals (defaults; dispatcher overrides before sourcing modules) ----
: "${DRY_RUN:=0}"
: "${ASSUME_YES:=0}"
: "${VERBOSE:=0}"
: "${APP_SLUG:=mailstead}"
: "${APP_LOG_DIR:=/var/log/${APP_SLUG}}"
: "${APP_LIB_DIR:=/var/lib/${APP_SLUG}}"
: "${APP_BACKUP_DIR:=/var/backups/${APP_SLUG}}"

# One timestamp per run, used for backup directories and log lines.
RUN_TS="${RUN_TS:-$(date +%Y%m%dT%H%M%S)}"
LOG_FILE="${LOG_FILE:-${APP_LOG_DIR}/${APP_SLUG}.log}"

# ---- logging ----
_c_log_write() {
    local level="$1"
    shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    # Never let logging itself kill the run.
    if [[ -n "${LOG_FILE:-}" ]]; then
        local dir
        dir="$(dirname -- "$LOG_FILE")"
        [[ -d "$dir" ]] || mkdir -p "$dir" 2>/dev/null || true
        if [[ -d "$dir" ]]; then
            printf '%s [%s] %s\n' "$ts" "$level" "$msg" >>"$LOG_FILE" 2>/dev/null || true
        fi
    fi
}

log_info() {
    _c_log_write INFO "$*"
    printf '%s\n' "$*"
}
log_warn() {
    _c_log_write WARN "$*"
    printf 'WARN: %s\n' "$*" >&2
}
log_err() {
    _c_log_write ERROR "$*"
    printf 'ERROR: %s\n' "$*" >&2
}
log_debug() {
    ((VERBOSE)) || return 0
    _c_log_write DEBUG "$*"
    printf 'DEBUG: %s\n' "$*" >&2
}

die() {
    local msg="$1" code="${2:-1}"
    log_err "$msg"
    exit "$code"
}

on_error() {
    local rc="$1" line="$2" cmd="$3"
    log_err "unexpected failure (rc=${rc}) at line ${line}: ${cmd}"
    log_err "see the log: ${LOG_FILE}"
    exit "${rc:-1}"
}

# ---- command execution ----
# run: execute a command, logging it; under --dry-run print and skip.
run() {
    if ((DRY_RUN)); then
        log_info "[dry-run] $*"
        return 0
    fi
    log_debug "+ $*"
    "$@"
}

# run_secret: like run but the argument list is not echoed (for passwords).
run_secret() {
    if ((DRY_RUN)); then
        log_info "[dry-run] $1 <args redacted>"
        return 0
    fi
    log_debug "+ $1 (args redacted)"
    "$@"
}

confirm() {
    local prompt="$1"
    if ((ASSUME_YES)); then
        log_info "${prompt} [yes]"
        return 0
    fi
    local reply=""
    if [[ -t 0 ]]; then
        read -r -p "${prompt} [y/N] " reply
    elif [[ -r /dev/tty ]]; then
        read -r -p "${prompt} [y/N] " reply </dev/tty
    else
        log_warn "${prompt} (no TTY available; assuming no)"
        return 1
    fi
    case "$reply" in
        [yY] | [yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        die "${APP_CMD:-mailstead} must be run as root." 1
    fi
}

# ---- validators ----
validate_domain() {
    local d="${1,,}"
    [[ "$d" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$ ]]
}

validate_email() {
    local e="${1,,}"
    local local_part domain
    local_part="${e%%@*}"
    domain="${e#*@}"
    [[ "$e" == *@* ]] || return 1
    [[ "$local_part" =~ ^[a-z0-9._%+-]{1,64}$ ]] || return 1
    [[ "$domain" != "$e" ]] || return 1
    validate_domain "$domain"
}

validate_hostname() {
    # A domain (FQDN) that must resolve; same grammar as validate_domain.
    validate_domain "$1"
}

require_domain() {
    validate_domain "$1" || die "invalid domain name: $1"
}

require_email() {
    validate_email "$1" || die "invalid email address: $1"
}

# ---- password / random ----
gen_password() {
    local len="${1:-32}"
    # alnum only, so it can never break config files or shells.
    openssl rand -base64 72 | tr -dc 'A-Za-z0-9' | head -c "$len"
}

gen_hex() {
    local len="${1:-24}"
    openssl rand -hex 64 | head -c "$len"
}

# ---- backup ----
backup_file() {
    local path="$1"
    [[ -e "$path" ]] || return 0
    local dest="${APP_BACKUP_DIR}/${RUN_TS}"
    local rel
    rel="${path#/}"
    if ((DRY_RUN)); then
        log_info "[dry-run] backup ${path} -> ${dest}/${rel}"
        return 0
    fi
    mkdir -p "${dest}/$(dirname -- "$rel")"
    cp -a -- "$path" "${dest}/${rel}"
    log_debug "backup: ${dest}/${rel}"
    printf '%s\n' "${dest}/${rel}" >>"${dest}/.index"
}

# ---- template rendering (NO sed/envsubst) ----
# tpl_var_value NAME -> prints value or empty
tpl_var_value() {
    local name="$1"
    if declare -p "$name" >/dev/null 2>&1; then
        printf '%s' "${!name}"
    else
        printf ''
    fi
}

# _tpl_replace_var CONTENT NEEDLE VALUE
# Replaces every occurrence of NEEDLE with VALUE and stores the result in the
# global TPL_RESULT. Uses literal prefix/suffix splitting (not ${var//pat/rep})
# so it is safe on Bash 5.3+, where an "&" in the replacement means "the match".
# A global is used instead of command substitution to preserve trailing newlines.
_tpl_replace_var() {
    local content="$1" needle="$2" value="$3"
    local out="" rest="$content"
    while [[ "$rest" == *"$needle"* ]]; do
        out+="${rest%%"$needle"*}"
        out+="$value"
        rest="${rest#*"$needle"}"
    done
    TPL_RESULT="${out}${rest}"
}

# render_template SRC DST [MODE] [OWNER:GROUP]
render_template() {
    local src="$1" dst="$2" mode="${3:-0644}" owner="${4:-root:root}"
    [[ -r "$src" ]] || die "template not found: ${src}"
    local content
    content="$(cat -- "$src")"

    local -a names=()
    IFS=$' \t\n' read -r -a names <<<"${TPL_VARS:-}"
    local name val
    for name in "${names[@]+"${names[@]}"}"; do
        val="$(tpl_var_value "$name")"
        _tpl_replace_var "$content" "@@${name}@@" "$val"
        content="$TPL_RESULT"
    done

    if [[ "$content" =~ @@([A-Z_][A-Z0-9_]*)@@ ]]; then
        die "render_template: unsubstituted placeholder '${BASH_REMATCH[0]}' in ${src}"
    fi

    local tmp
    tmp="$(mktemp "${dst}.XXXXXX" 2>/dev/null || mktemp /tmp/render.XXXXXX)"
    printf '%s' "$content" >"$tmp"

    local u="${owner%%:*}" g="${owner##*:}"
    if ((DRY_RUN)); then
        log_info "[dry-run] render ${src} -> ${dst} (${mode} ${owner})"
        rm -f -- "$tmp"
        return 0
    fi
    local dstdir
    dstdir="$(dirname -- "$dst")"
    [[ -d "$dstdir" ]] || install -d -m 0755 -- "$dstdir"
    install -m "$mode" -o "$u" -g "$g" -- "$tmp" "$dst"
    rm -f -- "$tmp"
    log_debug "created ${dst} from ${src}"
}

# XML-escape a value for placing inside an XML text/attribute node.
# Character loop avoids ${var//pat/&amp;} which Bash 5.3+ would mis-handle.
xml_escape() {
    local s="$1" out="" ch i
    local n="${#s}"
    for ((i = 0; i < n; i++)); do
        ch="${s:i:1}"
        case "$ch" in
            '&') out+='&amp;' ;;
            '<') out+='&lt;' ;;
            '>') out+='&gt;' ;;
            '"') out+='&quot;' ;;
            *) out+="$ch" ;;
        esac
    done
    printf '%s' "$out"
}

# ---- Postfix config application ----
# postconf_apply_file FILE: each non-empty, non-comment "key = value" line
# is applied with `postconf -e`. Never rewrites main.cf directly.
postconf_apply_file() {
    local file="$1" line
    [[ -r "$file" ]] || die "Postfix config file not found: ${file}"
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" == *=* ]] || continue
        run postconf -e "$line"
    done <"$file"
}

# ---- phase / state ----
phase_path() { printf '%s/phases/%s.done' "$APP_LIB_DIR" "$1"; }

phase_done() { [[ -f "$(phase_path "$1")" ]]; }

phase_mark() {
    local p="$1"
    if ((DRY_RUN)); then
        log_info "[dry-run] phase mark ${p}"
        return 0
    fi
    mkdir -p "${APP_LIB_DIR}/phases"
    date '+%Y-%m-%dT%H:%M:%S' >"$(phase_path "$p")"
    log_debug "phase ${p} complete"
}

phase_unmark() { rm -f -- "$(phase_path "$1")"; }

state_file() { printf '%s/state.env' "$APP_LIB_DIR"; }

state_get() {
    local key="$1" file
    file="$(state_file)"
    [[ -f "$file" ]] || return 1
    local line
    line="$(grep -E "^${key}=" "$file" | tail -n1 || true)"
    [[ -n "$line" ]] || return 1
    printf '%s' "${line#*=}"
}

state_set() {
    local key="$1" val="${2-}" file
    file="$(state_file)"
    if ((DRY_RUN)); then
        log_info "[dry-run] state ${key}=${val}"
        return 0
    fi
    mkdir -p "$(dirname -- "$file")"
    touch "$file"
    # strip any previous value
    local tmp
    tmp="$(mktemp)"
    grep -vE "^${key}=" "$file" >"$tmp" 2>/dev/null || true
    printf '%s=%s\n' "$key" "$val" >>"$tmp"
    mv -f -- "$tmp" "$file"
    chmod 0600 "$file" 2>/dev/null || true
}

# ---- service helpers ----
svc_reload_safe() {
    # svc_reload_safe SERVICE CHECK_CMD...
    local svc="$1"
    shift
    if ((DRY_RUN)); then
        log_info "[dry-run] check+reload ${svc}"
        return 0
    fi
    if ! "$@"; then
        die "verification failed before reloading ${svc}: $*"
    fi
    systemctl reload "$svc" || die "systemctl reload ${svc} failed"
}

wait_for_port() {
    local host="$1" port="$2" timeout="${3:-30}" i
    for ((i = 0; i < timeout; i++)); do
        if (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null; then
            exec 3>&- 3<&- 2>/dev/null || true
            return 0
        fi
        sleep 1
    done
    return 1
}

# file_mode_owner PATH MODE OWNER:GROUP  (idempotent chmod/chown)
file_mode_owner() {
    local path="$1" mode="$2" owner="$3"
    ((DRY_RUN)) && {
        log_info "[dry-run] chmod ${mode} chown ${owner} ${path}"
        return 0
    }
    [[ -e "$path" ]] || return 0
    chmod "$mode" "$path" 2>/dev/null || true
    chown "$owner" "$path" 2>/dev/null || true
}

# Write a value to secrets file (0600) if absent; print existing otherwise.
secret_path() { printf '%s/secrets/%s.pw' "${APP_ETC_DIR:-/etc/${APP_SLUG}}" "$1"; }

secret_get() {
    local f
    f="$(secret_path "$1")"
    [[ -f "$f" ]] || return 1
    cat -- "$f"
}

secret_ensure() {
    # secret_ensure NAME [LEN] -> creates if missing, prints value.
    local name="$1" len="${2:-32}" f val
    f="$(secret_path "$name")"
    if ((DRY_RUN)); then
        log_info "[dry-run] secret ensure ${name}"
        printf 'DRYRUNPASSWORDDRYRUNPASSWORD'
        return 0
    fi
    if [[ -f "$f" ]]; then
        cat -- "$f"
        return 0
    fi
    mkdir -p "$(dirname -- "$f")"
    val="$(gen_password "$len")"
    (
        umask 077
        printf '%s' "$val" >"$f"
    )
    chmod 0600 "$f"
    printf '%s' "$val"
}

# Print a section header used across the CLI.
header() { printf '\n=== %s ===\n' "$*"; }

# ---- external downloads ----
load_versions() {
    local f="${APP_ROOT}/config/versions.env"
    [[ -r "$f" ]] || die "versions file not found: ${f}"
    # shellcheck disable=SC1090
    . "$f"
}

# download_verified URL DEST SHA256
# Honors --offline (OFFLINE=1): uses an existing file at DEST without network.
# Under --dry-run a missing file is never fatal: it previews the fetch and skips
# checksum verification (there is nothing on disk to verify yet).
download_verified() {
    local url="$1" dest="$2" sha="$3"
    if [[ -f "$dest" ]]; then
        log_info "file already present: ${dest}"
    else
        if ((DRY_RUN)); then
            log_info "[dry-run] would fetch ${url} -> ${dest}"
            return 0
        fi
        if ((${OFFLINE:-0})); then
            die "--offline is enabled and the file is missing: ${dest}. Provide it locally and try again."
        fi
        mkdir -p "$(dirname -- "$dest")"
        local tmp="${dest}.part"
        curl -fSL --retry 3 --retry-delay 2 -o "$tmp" "$url" ||
            die "download failed: ${url}"
        mv -f -- "$tmp" "$dest"
    fi
    if [[ -n "$sha" ]]; then
        local got
        got="$(sha256sum -- "$dest" | awk '{print $1}')"
        if [[ "$got" != "$sha" ]]; then
            rm -f -- "$dest"
            die "sha256 verification failed for ${dest}: expected ${sha} got ${got}. File removed."
        fi
        log_info "sha256 verification ok: ${dest}"
    else
        log_warn "no checksum known for ${dest}; verify manually. sha256=$(sha256sum -- "$dest" | awk '{print $1}')"
    fi
}
