#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Command Dispatch and Subcommands
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

# shellcheck shell=bash

STANDARD_ALIASES=(postmaster abuse hostmaster dmarc tls-reports)

cli_standard_aliases() {
    local domain="$1" a
    local target="${ADMIN_EMAIL:-postmaster@${domain}}"
    for a in "${STANDARD_ALIASES[@]}"; do
        db_add_alias "${a}@${domain}" "$target"
    done
}

signatures_render_user() {
    [[ "$(comp_get signatures)" != "none" ]] || return 0
    command -v python3 >/dev/null 2>&1 || {
        log_warn "python3 is missing; skipping signature generation."
        return 0
    }
    sig_render_user "$1" || log_warn "could not generate the signature for $1"
}

cmd_add_domain() {
    local domain="" no_web=0 display=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-web)
                no_web=1
                shift
                ;;
            --display-name)
                display="$2"
                shift 2
                ;;
            --*) die "unknown option: $1" "$EX_USAGE" ;;
            *)
                domain="$1"
                shift
                ;;
        esac
    done
    require_config
    [[ -n "$domain" ]] || die "usage: ${APP_CMD} add-domain DOMAIN [--no-web]" "$EX_USAGE"
    require_domain "$domain"
    if end_domain_exists "$domain"; then die "domain already exists: ${domain}"; fi

    db_add_domain "$domain" "${display:-}"
    cli_standard_aliases "$domain"

    if [[ "$(comp_get dkim)" == "opendkim" ]]; then
        dkim_add_domain "$domain"
    fi

    if [[ "$no_web" == "0" ]]; then
        if [[ "$(comp_get mta-sts)" == "yes" ]]; then mta_sts_add_domain "$domain"; fi
        autoconfig_add_domain "$domain" "${display:-$domain}"
    fi

    cmd_dns_print "$domain" >/dev/null 2>&1 || true
    header "domain ${domain} ready"
    dns_records_print "$domain"
    log_info "publish the records above, then run: ${APP_CMD} dns-check ${domain}"
}

end_domain_exists() { db_domain_exists "$1"; }

cmd_del_domain() {
    local domain="" purge=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --purge-mail)
                purge=1
                shift
                ;;
            --yes) shift ;;
            *)
                domain="$1"
                shift
                ;;
        esac
    done
    require_config
    [[ -n "$domain" ]] || die "usage: ${APP_CMD} del-domain DOMAIN --yes" "$EX_USAGE"
    require_domain "$domain"
    confirm "delete the domain ${domain} and all its mailboxes?" || die "cancelled." "$EX_OK"

    if [[ "$purge" == "1" && -d "/var/vmail/${domain}" ]]; then
        backup_file "/var/vmail/${domain}"
        ((DRY_RUN)) || rm -rf -- "/var/vmail/${domain}"
    fi

    if [[ "$(comp_get dkim)" == "opendkim" ]]; then dkim_remove_domain "$domain" || true; fi
    autoconfig_del_domain "$domain" || true
    if [[ "$(comp_get mta-sts)" == "yes" ]]; then
        nginx_remove_vhost "mta-sts-${domain}"
        local d="${APP_LIB}/web/mta-sts/${domain}"
        [[ -d "$d" ]] && {
            backup_file "$d"
            ((DRY_RUN)) || rm -rf -- "$d"
        }
    fi
    if [[ "$(comp_get signatures)" != "none" ]]; then
        local sd="${APP_LIB}/signatures/domains/${domain}" sr="${APP_LIB}/signatures/rendered/${domain}"
        [[ -d "$sd" ]] && backup_file "$sd"
        [[ -d "$sr" ]] && backup_file "$sr"
        ((DRY_RUN)) || rm -rf -- "$sd" "$sr"
    fi

    db_del_domain "$domain"
    if [[ "$(comp_get webserver)" == "nginx" ]]; then nginx_reload_safe; fi
    log_info "deleted the domain ${domain}. Update the published DNS records."
}

cmd_add_mailbox() {
    local email="" pw="auto" quota="0" name="" title="" phone=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --password)
                pw="$2"
                shift 2
                ;;
            --quota)
                quota="$2"
                shift 2
                ;;
            --name)
                name="$2"
                shift 2
                ;;
            --title)
                title="$2"
                shift 2
                ;;
            --phone)
                phone="$2"
                shift 2
                ;;
            *)
                email="$1"
                shift
                ;;
        esac
    done
    require_config
    [[ -n "$email" ]] || die "usage: ${APP_CMD} add-mailbox user@domain [options]" "$EX_USAGE"
    require_email "$email"

    if [[ "$pw" == "auto" ]]; then pw="$(gen_password 20)"; fi
    local quota_bytes=$((quota * 1048576))
    db_add_mailbox "$email" "$pw" "$quota_bytes" "$name"

    if [[ "$(comp_get signatures)" != "none" ]]; then
        local domain="${email#*@}" local_part="${email%%@*}"
        [[ -n "$name" ]] && sig_env_set "$(sig_user_env "$domain" "$local_part")" NAME "$name"
        [[ -n "$title" ]] && sig_env_set "$(sig_user_env "$domain" "$local_part")" TITLE "$title"
        [[ -n "$phone" ]] && sig_env_set "$(sig_user_env "$domain" "$local_part")" PHONE "$phone"
        signatures_render_user "$email"
    fi

    log_info "created the mailbox ${email}."
    printf 'password: %s\n' "$pw"
}

cmd_del_mailbox() {
    local email="" purge=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --purge-mail)
                purge=1
                shift
                ;;
            --yes) shift ;;
            *)
                email="$1"
                shift
                ;;
        esac
    done
    require_config
    require_email "$email"
    confirm "delete the mailbox ${email}?" || die "cancelled." "$EX_OK"
    if [[ "$purge" == "1" ]]; then
        local domain="${email#*@}" local_part="${email%%@*}"
        ((DRY_RUN)) || rm -rf -- "/var/vmail/${domain}/${local_part}"
    fi
    db_del_mailbox "$email"
    if [[ "$(comp_get signatures)" != "none" ]]; then
        local d="${email#*@}" l="${email%%@*}"
        rm -f -- "$(sig_user_env "$d" "$l")" "$(sig_rendered_dir "$d")/${l}.html" "$(sig_rendered_dir "$d")/${l}.txt" 2>/dev/null || true
    fi
    log_info "deleted the mailbox ${email}."
}

cmd_passwd() {
    local email="" pw="auto"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --password)
                pw="$2"
                shift 2
                ;;
            *)
                email="$1"
                shift
                ;;
        esac
    done
    require_config
    require_email "$email"
    if [[ "$pw" == "auto" ]]; then pw="$(gen_password 20)"; fi
    db_set_password "$email" "$pw"
    log_info "updated the password for ${email}."
    printf 'new password: %s\n' "$pw"
}

cmd_add_alias() {
    require_config
    local address="${1:-}" targets="${2:-}"
    [[ -n "$address" && -n "$targets" ]] || die "usage: ${APP_CMD} add-alias alias@domain target1,target2" "$EX_USAGE"
    require_email "$address"
    db_add_alias "$address" "${targets/,/,}"
    log_info "added the alias ${address} -> ${targets}."
}

cmd_del_alias() {
    require_config
    local address="${1:-}"
    require_email "$address"
    db_del_alias "$address"
    log_info "deleted the alias ${address}."
}

cmd_list() {
    require_config
    db_require
    local what="${1:-domains}" domain="${2:-}"
    case "$what" in
        domains)
            header "domains"
            db_list_domains
            ;;
        mailboxes)
            header "mailboxes"
            db_list_mailboxes "$domain"
            ;;
        aliases)
            header "aliases"
            db_list_aliases "$domain"
            ;;
        *) die "usage: ${APP_CMD} list domains|mailboxes|aliases [DOMAIN]" "$EX_USAGE" ;;
    esac
}

cmd_components() {
    local sub="${1:-list}"
    shift || true
    case "$sub" in
        list)
            config_load || true
            components_load || { components_defaults; }
            _components_print_table
            ;;
        add)
            require_config
            local comp="${1:-}"
            [[ -n "$comp" ]] || die "usage: ${APP_CMD} components add COMPONENT" "$EX_USAGE"
            components_load || components_defaults
            case "$comp" in
                webmail) comp_set webmail roundcube ;;
                dashboard) comp_set dashboard postfixadmin ;;
                spam) comp_set spam rspamd ;;
                dkim) comp_set dkim opendkim ;;
                autoconfig) comp_set autoconfig all ;;
                signatures) comp_set signatures client ;;
                mta-sts) comp_set mta-sts yes ;;
                db) comp_set db mariadb ;;
                webserver) comp_set webserver nginx ;;
                *) comp_set "$comp" yes ;;
            esac
            resolve_components
            log_info "running the missing phases for component ${comp}..."
            install_run_phases
            log_info "component ${comp} added."
            ;;
        remove)
            require_config
            local comp="${1:-}"
            [[ -n "$comp" ]] || die "usage: ${APP_CMD} components remove COMPONENT --yes" "$EX_USAGE"
            confirm "remove component ${comp} (without deleting user data)?" || die "cancelled." "$EX_OK"
            components_load || components_defaults
            case "$comp" in
                webmail)
                    comp_set webmail none
                    nginx_remove_vhost mail
                    ;;
                dashboard)
                    comp_set dashboard none
                    nginx_remove_vhost admin
                    ;;
                spam) comp_set spam none ;;
                dkim) comp_set dkim none ;;
                autoconfig)
                    comp_set autoconfig none
                    local d
                    while read -r d; do [[ -n "$d" ]] && autoconfig_del_domain "$d"; done < <(db_list_domains)
                    ;;
                mta-sts)
                    comp_set mta-sts none
                    local d
                    while read -r d; do [[ -n "$d" ]] && nginx_remove_vhost "mta-sts-${d}"; done < <(db_list_domains)
                    ;;
                *) comp_set "$comp" none ;;
            esac
            resolve_components
            if [[ "$(comp_get webserver)" == "nginx" ]]; then nginx_reload_safe; fi
            log_warn "component ${comp} removed from the config. Packages and user data were not deleted (see docs)."
            ;;
        *) die "unknown: ${sub}" "$EX_USAGE" ;;
    esac
}

cmd_wizard() {
    require_config 2>/dev/null || true
    components_defaults
    local preset="standard"
    if command -v whiptail >/dev/null 2>&1; then
        whiptail --title "${APP_NAME}" --msgbox "Interactive setup wizard" 8 50 2>/dev/null || true
        preset="$(whiptail --title "${APP_NAME}" --menu "choose a preset:" 15 60 4 \
            standard "webmail + spam" minimal "no web" full "everything" send-only "send only" 3>&1 1>&2 2>&3)" || preset="standard"
    else
        printf 'choose a preset [standard/minimal/full/send-only] (default standard): '
        read -r preset
        [[ -z "$preset" ]] && preset="standard"
    fi
    apply_preset "$preset"
    resolve_components
    log_info "run: ${APP_CMD} install --preset ${preset} --hostname mail.<domain> --domain <domain> --admin-email admin@<domain>"
}
