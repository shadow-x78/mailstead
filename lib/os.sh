#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Operating System Detection
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

os_init() {
    local force="${1:-}"
    # shellcheck source=lib/distro/detect.sh
    . "${APP_ROOT}/lib/distro/detect.sh"
    distro_detect "$force"
    distro_load_pkgmap
    distro_load_family

    APP_ETC_DIR="$APP_ETC"
    APP_LIB_DIR="$APP_LIB"
    APP_LOG_DIR="$APP_LOG"
    APP_BACKUP_DIR="$APP_BACKUP"

    export APP_ETC_DIR APP_LIB_DIR APP_LOG_DIR APP_BACKUP_DIR
    export DISTRO_FAMILY PKG_MGR
}

ensure_dir() {
    local dir="$1" mode="${2:-0755}" owner="${3:-root:root}"
    if ((DRY_RUN)); then
        log_info "[dry-run] mkdir -p ${dir} (${mode} ${owner})"
        return 0
    fi
    local u="${owner%%:*}" g="${owner##*:}"
    # The group may not exist before the owning package is installed.
    if ! getent group "$g" >/dev/null 2>&1; then
        g="$(id -gn "$u" 2>/dev/null || printf 'root')"
    fi
    install -d -m "$mode" -o "$u" -g "$g" -- "$dir"
}

ensure_group() {
    local group="$1" gid="${2:-}"
    getent group "$group" >/dev/null 2>&1 && return 0
    if ((DRY_RUN)); then
        log_info "[dry-run] groupadd ${group}"
        return 0
    fi
    if [[ -n "$gid" ]]; then groupadd -g "$gid" "$group"; else groupadd -r "$group"; fi
}

ensure_user() {
    local user="$1" uid="$2" home="$3" shell="${4:-/usr/sbin/nologin}" group="${5:-$1}"
    id -u "$user" >/dev/null 2>&1 && return 0
    if ((DRY_RUN)); then
        log_info "[dry-run] useradd ${user}"
        return 0
    fi
    local -a args=(-r -m -d "$home" -s "$shell" -g "$group")
    [[ -n "$uid" ]] && args+=(-u "$uid")
    useradd "${args[@]}" "$user"
}

ensure_system_user() {
    local user="$1" shell="${2:-/usr/sbin/nologin}"
    id -u "$user" >/dev/null 2>&1 && return 0
    if ((DRY_RUN)); then
        log_info "[dry-run] useradd -r ${user}"
        return 0
    fi
    useradd -r -s "$shell" -M "$user"
}

ensure_vmail_user() {
    if ((DRY_RUN)); then
        log_info "[dry-run] ensure vmail user (uid/gid 5000)"
        return 0
    fi
    if ! getent group vmail >/dev/null 2>&1; then
        groupadd -g 5000 vmail
    fi
    if ! id -u vmail >/dev/null 2>&1; then
        useradd -r -g vmail -u 5000 -d /var/vmail -s /usr/sbin/nologin -M vmail
    fi
    install -d -m 0770 -o vmail -g vmail /var/vmail
}

svc_exists() {
    systemctl list-unit-files --type=service "$1.service" --no-legend 2>/dev/null | grep -q .
}

systemd_unit_exists() {
    local unit="$1"
    [[ "$unit" == *.service ]] || unit="${unit}.service"
    systemctl list-unit-files --type=service "$unit" --no-legend 2>/dev/null | grep -q .
}

detect_public_ip4() {
    local ip=""
    if ((${OFFLINE:-0})); then
        if command -v ip >/dev/null 2>&1; then
            ip="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n1 || true)"
        fi
        printf '%s' "$ip"
        return 0
    fi
    if command -v curl >/dev/null 2>&1; then
        ip="$(curl -4 -fsS --max-time 8 https://api.ipify.org 2>/dev/null || true)"
    fi
    if [[ -z "$ip" ]] && command -v ip >/dev/null 2>&1; then
        ip="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n1 || true)"
    fi
    printf '%s' "$ip"
}

is_port_listening() {
    local port="$1"
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${port}\$"
}
