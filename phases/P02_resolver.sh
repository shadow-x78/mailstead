#!/usr/bin/env bash
# phases/P02_resolver.sh - local unbound resolver (optional, default yes).
PHASE_REQUIRES=""

phase_P02() {
    if [[ "$(comp_get resolver)" != "unbound" ]]; then
        log_info "P02: resolver=system (skipping unbound)."
        return 0
    fi
    header "P02 local resolver"
    local dir conf
    dir="$(path unbound_conf_d)"
    conf="${dir}/${APP_SLUG}.conf"
    ensure_dir "$dir" 0755 root:root
    if ((DRY_RUN)); then
        log_info "[dry-run] write unbound conf"
        return 0
    fi
    cat >"$conf" <<EOF
# ${APP_MANAGED_MARK}
server:
    interface: 127.0.0.1
    access-control: 127.0.0.0/8 allow
    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
    harden-glue: yes
    prefetch: yes
    do-not-query-localhost: no
EOF
    chmod 0644 "$conf"
    systemctl restart unbound 2>/dev/null || systemctl start unbound 2>/dev/null || true

    if ! dig +short +time=3 @127.0.0.1 example.com >/dev/null 2>&1; then
        log_warn "unbound is not responding; leaving resolv.conf as-is (DNSBL may not work)."
        return 0
    fi

    # Point the system at 127.0.0.1 with a public fallback.
    backup_file /etc/resolv.conf
    if systemctl is-active --quiet systemd-resolved; then
        systemctl disable --now systemd-resolved 2>/dev/null || true
    fi
    cat >/etc/resolv.conf <<EOF
# ${APP_MANAGED_MARK}
nameserver 127.0.0.1
nameserver 1.1.1.1
EOF
    chmod 0644 /etc/resolv.conf
    log_warn "cloud-init/netplan may rewrite /etc/resolv.conf; verify after a reboot."
}
