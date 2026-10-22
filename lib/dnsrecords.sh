#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - DNS Record Builder and Verifier
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

# shellcheck shell=bash

DNS_PUBLIC_RESOLVERS=(1.1.1.1 8.8.8.8)

dns_domain_ip4() { state_get IP4 2>/dev/null || printf ''; }
dns_domain_ip6() { state_get IP6 2>/dev/null || printf ''; }

dns_records_print() {
    local domain="$1"
    require_domain "$domain"
    local ip4 ip6 host sel rec
    ip4="$(dns_domain_ip4)"
    ip6="$(dns_domain_ip6)"
    host="$MAIL_HOSTNAME"
    sel="$(dkim_selector "$domain")"
    rec="$(dkim_record_string "$domain" "$sel" 2>/dev/null || printf 'v=DKIM1; h=sha256; k=rsa; p=<KEY>')"

    local spf="v=spf1 mx"
    [[ -n "$ip4" ]] && spf+=" ip4:${ip4}"
    [[ -n "$ip6" ]] && spf+=" ip6:${ip6}"
    spf+=" -all"

    header "DNS records for ${domain}"
    cat <<EOF
; ${domain}
${host}.                A      ${ip4}
${domain}.              MX 10  ${host}.
${domain}.              TXT    "${spf}"
${host}.                TXT    "v=spf1 a -all"
${sel}._domainkey.${domain}. TXT "${rec}"
_dmarc.${domain}.       TXT    "v=DMARC1; p=none; rua=mailto:dmarc@${domain}; fo=1; adkim=r; aspf=r; pct=100"
${domain}.              CAA    0 issue "letsencrypt.org"
_submission._tcp.${domain}. SRV 0 1 587 ${host}.
_imaps._tcp.${domain}.  SRV    0 1 993 ${host}.
EOF
    if [[ -n "$ip6" ]]; then
        printf '%s.                AAAA   %s\n' "$host" "$ip6"
    fi
    if [[ "$(comp_get mta-sts)" == "yes" ]]; then
        printf '%s.        TXT    "v=STSv1; id=%s"\n' "_mta-sts.${domain}" "$(date +%Y%m%d%H%M%S)"
        printf '%s.        A      %s\n' "mta-sts.${domain}" "$ip4"
        printf '%s.      TXT    "v=TLSRPTv1; rua=mailto:tls-reports@%s"\n' "_smtp._tls.${domain}" "$domain"
    fi
    if [[ "$(comp_get autoconfig)" != "none" ]]; then
        printf '%s.      A      %s\n' "autoconfig.${domain}" "$ip4"
        printf '%s.      A      %s\n' "autodiscover.${domain}" "$ip4"
        printf '%s. SRV 0 1 443 autodiscover.%s.\n' "_autodiscover._tcp.${domain}" "$domain"
    fi

    header "summary table"
    printf '%-45s %-6s %s\n' "NAME" "TYPE" "VALUE"
    printf '%-45s %-6s %s\n' "${host}." "A" "${ip4}"
    [[ -n "$ip6" ]] && printf '%-45s %-6s %s\n' "${host}." "AAAA" "${ip6}"
    printf '%-45s %-6s %s\n' "${domain}." "MX" "10 ${host}."
    printf '%-45s %-6s %s\n' "${domain}." "TXT" "${spf}"
    printf '%-45s %-6s %s\n' "${sel}._domainkey.${domain}." "TXT" "DKIM p=..."
    printf '%-45s %-6s %s\n' "_dmarc.${domain}." "TXT" "v=DMARC1; p=none; ..."
    printf '%-45s %-6s %s\n' "${domain}." "CAA" '0 issue "letsencrypt.org"'
    printf '\nPTR (from the provider panel): %s -> %s\n' "$ip4" "$host"
    printf 'DMARC path: p=none (2-4 weeks) -> quarantine pct=25 -> pct=100 -> reject\n'
}

dns_query() {
    local name="$1" type="${2:-A}" resolver="${3:-}"
    if [[ -n "$resolver" ]]; then
        dig +short +time=4 +tries=1 @"$resolver" "$name" "$type" 2>/dev/null
    else
        dig +short +time=4 +tries=1 "$name" "$type" 2>/dev/null
    fi
}

_dns_ok() { printf '  ✔ %s\n' "$1"; }
_dns_bad() { printf '  ✘ %s\n' "$1"; }

dns_check() {
    local domain="$1"
    require_domain "$domain"
    local ip4 host sel rec expect got r h fail=0
    ip4="$(dns_domain_ip4)"
    host="$MAIL_HOSTNAME"
    sel="$(dkim_selector "$domain")"
    rec="$(dkim_record_string "$domain" "$sel" 2>/dev/null || printf '')"

    header "DNS check for ${domain}"
    for r in "${DNS_PUBLIC_RESOLVERS[@]}"; do
        printf -- '-- resolver %s --\n' "$r"

        got="$(dns_query "$host" A "$r" | tr '\n' ' ')"
        if [[ "$got" == *"$ip4"* && -n "$ip4" ]]; then _dns_ok "A(${host}) = ${ip4}"; else
            _dns_bad "A(${host}): expected ${ip4}, got '${got}'"
            fail=1
        fi

        got="$(dns_query "$domain" MX "$r" | tr '\n' ' ')"
        if [[ "$got" == *"$host"* ]]; then _dns_ok "MX(${domain}) points to ${host}"; else
            _dns_bad "MX(${domain}): '${got}'"
            fail=1
        fi

        got="$(dns_query "$domain" TXT "$r" | tr '\n' ' ')"
        if [[ "$got" == *"v=spf1"* ]]; then _dns_ok "SPF(${domain}) present"; else
            _dns_bad "SPF(${domain}) missing"
            fail=1
        fi
        local spf_count
        spf_count="$(printf '%s' "$got" | grep -o 'v=spf1' | wc -l)"
        if ((spf_count > 1)); then
            _dns_bad "more than one SPF record (${spf_count})"
            fail=1
        fi

        got="$(dns_query "${sel}._domainkey.${domain}" TXT "$r" | tr -d '"' | tr '\n' ' ')"
        if [[ -n "$rec" && "$got" == *"$(printf '%s' "$rec" | tr -d ' ' | cut -c1-40)"* ]]; then
            _dns_ok "DKIM(${sel}) matches"
        else
            _dns_bad "DKIM(${sel}) does not match or is missing"
            fail=1
        fi

        got="$(dns_query "_dmarc.${domain}" TXT "$r" | tr '\n' ' ')"
        if [[ "$got" == *"v=DMARC1"* ]]; then _dns_ok "DMARC present"; else
            _dns_bad "DMARC missing"
            fail=1
        fi

        if [[ "$(comp_get autoconfig)" != "none" ]]; then
            for h in autoconfig autodiscover; do
                got="$(dns_query "${h}.${domain}" A "$r" | tr '\n' ' ')"
                if [[ "$got" == *"$ip4"* && -n "$ip4" ]]; then _dns_ok "A(${h}.${domain})"; else
                    _dns_bad "A(${h}.${domain})"
                    fail=1
                fi
            done
            got="$(dns_query "_autodiscover._tcp.${domain}" SRV "$r" | tr '\n' ' ')"
            if [[ "$got" == *"autodiscover"* ]]; then _dns_ok "SRV _autodiscover._tcp"; else
                _dns_bad "SRV _autodiscover._tcp missing"
                fail=1
            fi
        fi
        if [[ "$(comp_get mta-sts)" == "yes" ]]; then
            got="$(dns_query "_mta-sts.${domain}" TXT "$r" | tr '\n' ' ')"
            if [[ "$got" == *"v=STSv1"* ]]; then _dns_ok "MTA-STS TXT"; else
                _dns_bad "MTA-STS TXT missing"
                fail=1
            fi
        fi
        got="$(dns_query "_submission._tcp.${domain}" SRV "$r" | tr '\n' ' ')"
        if [[ "$got" == *"587"* ]]; then _dns_ok "SRV _submission._tcp"; else _dns_bad "SRV _submission._tcp missing"; fi
        got="$(dns_query "$domain" CAA "$r" | tr '\n' ' ')"
        if [[ "$got" == *"letsencrypt"* ]]; then _dns_ok "CAA letsencrypt"; else _dns_bad "CAA missing"; fi
    done

    local ptr
    ptr="$(dig +short -x "$ip4" 2>/dev/null | tr -d '.' | tr '\n' ' ')"
    if [[ "$ptr" == *"$host"* ]]; then _dns_ok "PTR(IP) = ${host}"; else
        _dns_bad "PTR(IP) does not match ${host}: '${ptr}'"
        fail=1
    fi

    if ((fail)); then
        log_warn "some records are missing or do not match. Publish them, then re-check."
        return "$EX_ERR"
    fi
    log_info "all checked records are correct."
}

cmd_dns_print() {
    require_config
    local domain="${1:-}"
    [[ -n "$domain" ]] || die "usage: ${APP_CMD} dns-print DOMAIN" "$EX_USAGE"
    dns_records_print "$domain"
    local f="${APP_ETC}/dns/${domain}.txt"
    ((DRY_RUN)) && return 0
    ensure_dir "${APP_ETC}/dns" 0755 root:root
    dns_records_print "$domain" >"$f"
    log_info "saved to ${f}"
}

cmd_dns_check() {
    require_config
    local domain="${1:-}"
    [[ -n "$domain" ]] || die "usage: ${APP_CMD} dns-check DOMAIN" "$EX_USAGE"
    dns_check "$domain"
}
