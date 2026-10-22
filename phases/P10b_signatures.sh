#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Email Signatures Phase
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

PHASE_REQUIRES="signatures"

phase_P10b() {
    header "P10b signatures"
    if ! command -v python3 >/dev/null 2>&1; then
        die "python3 is required for signatures." "$EX_ERR"
    fi
    ensure_dir "$(sig_root)" 0755 root:root
    ensure_dir "$(sig_templates_dir)" 0755 root:root
    ensure_dir "$(sig_root)/domains" 0750 root:root
    ensure_dir "$(sig_root)/assets" 0755 root:"$(web_user)"
    ensure_dir "$(sig_root)/rendered" 0750 root:"$(web_user)"

    local profile
    profile="$(sig_profile_env "$PRIMARY_DOMAIN")"
    if [[ ! -f "$profile" ]]; then
        sig_env_set "$profile" ORG "$PRIMARY_DOMAIN"
        sig_env_set "$profile" ACCENT "#0a66c2"
        sig_env_set "$profile" TEMPLATE "classic-html"
        sig_env_set "$profile" DIR "ltr"
    fi

    local email
    while read -r email; do
        [[ -n "$email" ]] && signatures_render_user "$email"
    done < <(db_list_mailboxes "$PRIMARY_DOMAIN")

    if [[ "$(comp_get signatures)" == "server" ]]; then
        cmd_sig_server enable
    fi
    log_info "the signatures system is ready."
}
