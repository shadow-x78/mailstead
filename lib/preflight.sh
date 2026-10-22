#!/usr/bin/env bash
# shellcheck shell=bash

preflight_hostname() {
    run hostnamectl set-hostname "$MAIL_HOSTNAME"
    ((DRY_RUN)) && return 0
    printf '%s\n' "$MAIL_HOSTNAME" >/etc/hostname
    printf '%s\n' "$PRIMARY_DOMAIN" >/etc/mailname
    local ip4
    ip4="$(state_get IP4 2>/dev/null || printf '')"
    [[ -n "$ip4" ]] && preflight_hosts_line "$ip4" "$MAIL_HOSTNAME"
    return 0
}

preflight_hosts_line() {
    local ip="$1" host="$2" f="/etc/hosts"
    if grep -qE "[[:space:]]${host}([[:space:]]|$)" "$f"; then return 0; fi
    backup_file "$f"
    printf '%s %s %s\n' "$ip" "$host" "${host%%.*}" >>"$f"
}

preflight_resources() {
    local mem_mb
    mem_mb="$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || printf 0)"
    ((mem_mb < 1800)) && log_warn "memory ${mem_mb}MB is below the recommended 2GB."
    return 0
}

preflight_ports() {
    local p
    for p in 25 80 443 465 587 993; do
        if is_port_listening "$p" && ! systemctl is-active --quiet postfix && ! systemctl is-active --quiet nginx; then
            log_warn "port ${p} is busy from another service."
        fi
    done
    return 0
}

preflight_outbound_25() {
    if ! timeout 6 bash -c 'exec 3<>/dev/tcp/gmail-smtp-in.l.google.com/25' 2>/dev/null; then
        log_warn "outbound port 25 is blocked; outgoing mail may fail. Ask your provider to open it."
        confirm "continue despite blocked port 25?" || die "aborted: outbound port 25 is required." "$EX_PREFLIGHT"
    else
        log_info "outbound port 25 is open."
    fi
    return 0
}

preflight_dns() {
    local ip4 ptr a
    ip4="$(state_get IP4 2>/dev/null || printf '')"
    if [[ -n "$ip4" ]]; then
        ptr="$(dig +short -x "$ip4" 2>/dev/null | tr -d '.' | tr '\n' ' ')"
        [[ "$ptr" == *"$MAIL_HOSTNAME"* ]] || log_warn "PTR(${ip4}) does not match ${MAIL_HOSTNAME} ('${ptr}'). Set it in your provider's panel."
    fi
    a="$(dig +short "$MAIL_HOSTNAME" A 2>/dev/null | tail -n1)"
    [[ "$a" == "$ip4" ]] || log_warn "A(${MAIL_HOSTNAME})='${a}' does not match IP=${ip4}."
    return 0
}
