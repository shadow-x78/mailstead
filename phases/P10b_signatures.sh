#!/usr/bin/env bash
# phases/P10b_signatures.sh - signatures subsystem (plan-3 section F).
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

    # Seed the domain profile with defaults for the primary domain.
    local profile
    profile="$(sig_profile_env "$PRIMARY_DOMAIN")"
    if [[ ! -f "$profile" ]]; then
        sig_env_set "$profile" ORG "$PRIMARY_DOMAIN"
        sig_env_set "$profile" ACCENT "#0a66c2"
        sig_env_set "$profile" TEMPLATE "classic-html"
        sig_env_set "$profile" DIR "ltr"
    fi

    # Render signatures for existing mailboxes.
    local email
    while read -r email; do
        [[ -n "$email" ]] && signatures_render_user "$email"
    done < <(db_list_mailboxes "$PRIMARY_DOMAIN")

    if [[ "$(comp_get signatures)" == "server" ]]; then
        cmd_sig_server enable
    fi
    log_info "the signatures system is ready."
}
