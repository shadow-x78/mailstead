#!/usr/bin/env bash
# lib/components.sh - component selection: presets, flags, dependency resolver.
#
# Components are stored in COMP_<NAME> shell variables and persisted to
# ${APP_ETC}/components.env. Flags override presets; the config file overrides
# flags (handled by the dispatcher's apply order).

# Canonical component names and their preset defaults.
COMPONENT_NAMES=(
    mta mailbox webmail dashboard webserver db dkim spam antivirus sieve
    tls acme-client acme-challenge mta-sts autoconfig resolver firewall
    fail2ban signatures sig-policy sig-images
)

comp_var() { printf 'COMP_%s' "$(printf '%s' "$1" | tr 'a-z-' 'A-Z_')"; }

comp_get() {
    local v
    v="$(comp_var "$1")"
    if declare -p "$v" >/dev/null 2>&1; then printf '%s' "${!v}"; fi
}

comp_set() {
    local v
    v="$(comp_var "$1")"
    printf -v "$v" '%s' "$2"
}

components_defaults() {
    comp_set mta postfix
    comp_set mailbox yes
    comp_set webmail none
    comp_set dashboard none
    comp_set webserver none
    comp_set db mariadb
    comp_set dkim opendkim
    comp_set spam rspamd
    comp_set antivirus none
    comp_set sieve yes
    comp_set tls letsencrypt
    comp_set acme-client certbot
    comp_set acme-challenge http
    comp_set mta-sts no
    comp_set autoconfig none
    comp_set resolver unbound
    comp_set firewall auto
    comp_set fail2ban yes
    comp_set signatures none
    comp_set sig-policy default
    comp_set sig-images hosted
    comp_set mode cli
}

# apply_preset NAME - set every component for a named preset.
apply_preset() {
    local preset="$1"
    case "$preset" in
        send-only)
            comp_set mta postfix
            comp_set mailbox no
            comp_set webmail none
            comp_set dashboard none
            comp_set webserver none
            comp_set db none
            comp_set dkim opendkim
            comp_set spam none
            comp_set sieve no
            comp_set tls letsencrypt
            comp_set mta-sts no
            comp_set autoconfig none
            comp_set resolver system
            comp_set fail2ban yes
            comp_set firewall auto
            comp_set signatures none
            ;;
        minimal)
            comp_set mta postfix
            comp_set mailbox yes
            comp_set webmail none
            comp_set dashboard none
            comp_set webserver none
            comp_set db mariadb
            comp_set dkim opendkim
            comp_set spam rspamd
            comp_set sieve yes
            comp_set tls letsencrypt
            comp_set mta-sts no
            comp_set autoconfig none
            comp_set resolver system
            comp_set fail2ban yes
            comp_set firewall auto
            comp_set signatures none
            ;;
        standard)
            comp_set mta postfix
            comp_set mailbox yes
            comp_set webmail roundcube
            comp_set dashboard none
            comp_set webserver nginx
            comp_set db mariadb
            comp_set dkim opendkim
            comp_set spam rspamd
            comp_set sieve yes
            comp_set tls letsencrypt
            comp_set mta-sts no
            comp_set autoconfig all
            comp_set resolver system
            comp_set fail2ban yes
            comp_set firewall auto
            comp_set signatures client
            ;;
        full)
            comp_set mta postfix
            comp_set mailbox yes
            comp_set webmail roundcube
            comp_set dashboard postfixadmin
            comp_set webserver nginx
            comp_set db mariadb
            comp_set dkim opendkim
            comp_set spam rspamd
            comp_set sieve yes
            comp_set tls letsencrypt
            comp_set mta-sts yes
            comp_set autoconfig all
            comp_set resolver unbound
            comp_set fail2ban yes
            comp_set firewall auto
            comp_set signatures client
            ;;
        custom) : ;; # keep current/dafaults, flags/config fill the rest
        *)
            die "unknown preset: ${preset} (available: send-only, minimal, standard, full, custom)" 2
            ;;
    esac
}

# resolve_components - apply dependency rules, print the final table, persist.
resolve_components() {
    # MODE shortcut -> dashboard.
    case "$(comp_get mode)" in
        gui) comp_set dashboard postfixadmin ;;
        cli) comp_set dashboard none ;;
    esac

    # send-only normalisation.
    if [[ "$(comp_get mailbox)" == "no" && "$(comp_get webmail)" == "none" && "$(comp_get db)" == "none" ]]; then
        comp_set spam none
        comp_set sieve no
    fi

    # 1) webmail/dashboard need webserver + tls + db.
    if [[ "$(comp_get webmail)" != "none" || "$(comp_get dashboard)" != "none" ]]; then
        if [[ "$(comp_get webserver)" == "none" ]]; then
            log_info "webmail/dashboard require a web server: enabling nginx automatically."
            comp_set webserver nginx
        fi
        if [[ "$(comp_get db)" == "none" ]]; then
            log_info "webmail/dashboard require a database: enabling mariadb automatically."
            comp_set db mariadb
        fi
    fi

    # 9) autoconfig needs webserver + tls (+ php-fpm for outlook).
    if [[ "$(comp_get autoconfig)" != "none" ]]; then
        if [[ "$(comp_get webserver)" == "none" ]]; then
            log_info "autoconfig requires a web server: enabling nginx automatically."
            comp_set webserver nginx
        fi
    fi

    # 5) mta-sts / autoconfig need a webserver (or existing + static instructions).
    if [[ "$(comp_get mta-sts)" == "yes" && "$(comp_get webserver)" == "none" ]]; then
        die "mta-sts requires webserver (or webserver=existing to generate static files)." 2
    fi
    if [[ "$(comp_get autoconfig)" != "none" && "$(comp_get webserver)" == "none" ]]; then
        die "autoconfig requires webserver (or webserver=existing to generate static files)." 2
    fi

    # 10) signatures need python3; hosted images need a webserver.
    if [[ "$(comp_get signatures)" != "none" ]]; then
        if [[ "$(comp_get sig-images)" == "hosted" && "$(comp_get webserver)" == "none" ]]; then
            log_warn "hosted image signatures without a web server; text + user-entered links will be used instead."
        fi
    fi

    # 4) mailbox=yes without db in v1 is an error.
    if [[ "$(comp_get mailbox)" == "yes" && "$(comp_get db)" == "none" ]]; then
        die "mailbox=yes requires db (files mode coming in v2)." 2
    fi
    # 2) webmail without mailbox.
    if [[ "$(comp_get webmail)" != "none" && "$(comp_get mailbox)" == "no" ]]; then
        die "webmail without mailbox is meaningless." 2
    fi
    # 3) dashboard without db.
    if [[ "$(comp_get dashboard)" != "none" && "$(comp_get db)" == "none" ]]; then
        die "dashboard requires db." 2
    fi
    # 6) send-only keeps only dkim + tls.
    if [[ "$(comp_get mailbox)" == "no" ]]; then
        comp_set webmail none
        comp_set dashboard none
        comp_set sieve no
        comp_set spam none
        comp_set mta-sts no
        comp_set autoconfig none
        comp_set signatures none
    fi

    # 12) signatures=server needs dkim and mailbox.
    if [[ "$(comp_get signatures)" == "server" ]]; then
        [[ "$(comp_get dkim)" == "opendkim" ]] || die "signatures=server requires dkim=opendkim (footer ordering before DKIM)." 2
        [[ "$(comp_get mailbox)" == "yes" ]] || die "signatures=server requires mailbox=yes." 2
    fi

    # spam implies kv.
    if [[ "$(comp_get spam)" == "rspamd" ]]; then comp_set kv auto; else comp_set kv none; fi

    _components_print_table
    components_persist
}

_components_print_table() {
    header "Selected components"
    local name val
    for name in "${COMPONENT_NAMES[@]}"; do
        val="$(comp_get "$name")"
        printf '  %-16s %s\n' "$name" "${val:--}"
    done
    printf '  %-16s %s\n' "kv" "$(comp_get kv)"
}

components_persist() {
    local file="${APP_ETC}/components.env"
    if ((DRY_RUN)); then
        log_info "[dry-run] write ${file}"
        return 0
    fi
    mkdir -p "$APP_ETC"
    {
        local name
        for name in "${COMPONENT_NAMES[@]}"; do
            printf 'COMP_%s=%s\n' "$(printf '%s' "$name" | tr 'a-z-' 'A-Z_')" "$(comp_get "$name")"
        done
        printf 'COMP_KV=%s\n' "$(comp_get kv)"
    } >"$file"
    chmod 0640 "$file"
}

components_load() {
    local file="${APP_ETC}/components.env"
    [[ -r "$file" ]] || return 1
    local line key val
    while IFS= read -r line; do
        [[ "$line" == COMP_*=* ]] || continue
        key="${line%%=*}"
        val="${line#*=}"
        printf -v "$key" '%s' "$val"
    done <"$file"
    return 0
}

# phase_requires_check PHASE_REQUIRES_STRING
# Returns 0 if every required component is enabled; prints a skip reason otherwise.
phase_requires_check() {
    local reqs="$1" name val
    [[ -z "$reqs" ]] && return 0
    local -a words=()
    IFS=$' \t\n' read -r -a words <<<"$reqs"
    for name in "${words[@]+"${words[@]}"}"; do
        val="$(comp_get "$name")"
        case "$val" in
            "" | none | no)
                printf 'skipped: component %s is not enabled' "$name"
                return 1
                ;;
        esac
    done
    return 0
}
