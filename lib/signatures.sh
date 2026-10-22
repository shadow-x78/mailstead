#!/usr/bin/env bash
# shellcheck shell=bash

sig_root() { printf '%s/signatures' "$APP_LIB"; }
sig_templates_dir() { printf '%s/templates' "$(sig_root)"; }
sig_domain_dir() { printf '%s/domains/%s' "$(sig_root)" "$1"; }
sig_profile_env() { printf '%s/profile.env' "$(sig_domain_dir "$1")"; }
sig_user_env() { printf '%s/users/%s.env' "$(sig_domain_dir "$1")" "$2"; }
sig_assets_dir() { printf '%s/assets/%s' "$(sig_root)" "$1"; }
sig_rendered_dir() { printf '%s/rendered/%s' "$(sig_root)" "$1"; }

sig_py() { printf '%s/scripts/mailstead-sig.py' "$APP_ROOT"; }

sig_env_load() {
    local f="$1"
    [[ -r "$f" ]] || return 1
    local line key val
    while IFS= read -r line; do
        [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
        key="${line%%=*}"
        val="${line#*=}"
        printf -v "$key" '%s' "$val"
    done <"$f"
    return 0
}

sig_env_set() {
    local f="$1" key="$2" val="$3"
    if ((DRY_RUN)); then
        log_info "[dry-run] sig env ${key}=${val} in ${f}"
        return 0
    fi
    ensure_dir "$(dirname -- "$f")" 0750 root:root
    touch "$f"
    chmod 0640 "$f"
    local tmp
    tmp="$(mktemp)"
    grep -vE "^${key}=" "$f" >"$tmp" 2>/dev/null || true
    printf '%s=%s\n' "$key" "$val" >>"$tmp"
    mv -f -- "$tmp" "$f"
}

sig_resolve_values() {
    local domain="$1"
    local local_part="$2"
    local email="${local_part}@${domain}"
    unset NAME TITLE ORG WEBSITE ACCENT DIR DISCLAIMER TEMPLATE \
        LOGO_URL LOGO_W LOGO_H BANNER_URL BANNER_W BANNER_H BANNER_ALT BANNER_LINK \
        LOGO_FILE BANNER_FILE PHONE 2>/dev/null || true
    sig_env_load "$(sig_profile_env "$domain")" || true
    sig_env_load "$(sig_user_env "$domain" "$local_part")" || true

    NAME="${NAME:-$local_part}"
    TITLE="${TITLE:-}"
    ORG="${ORG:-}"
    WEBSITE="${WEBSITE:-}"
    ACCENT="${ACCENT:-#0a66c2}"
    DIR="${DIR:-ltr}"
    TEMPLATE="${TEMPLATE:-classic-html}"
    DISCLAIMER="${DISCLAIMER:-}"
    PHONE="${PHONE:-}"

    SIG_EMAIL="$email"
    SIG_PHONE="$PHONE"
    SIG_PHONE_RAW="$(printf '%s' "${PHONE:-}" | tr -cd '0-9+')"
    WEBSITE_LABEL="${WEBSITE#*://}"
    WEBSITE_LABEL="${WEBSITE_LABEL%/}"
    if [[ "$DIR" == "rtl" ]]; then
        DIR_CSS="text-align:right;"
    else
        DIR_CSS="text-align:left;"
    fi
    FONT_STACK="Tahoma, Arial, Helvetica, sans-serif"
}

sig_render_values_args() {
    local -a map=(
        "NAME=${NAME:-}" "TITLE=${TITLE:-}" "ORG=${ORG:-}" "EMAIL=${SIG_EMAIL:-}"
        "PHONE=${SIG_PHONE:-}" "PHONE_RAW=${SIG_PHONE_RAW:-}" "WEBSITE=${WEBSITE:-}"
        "WEBSITE_LABEL=${WEBSITE_LABEL:-}" "ACCENT=${ACCENT:-}" "DIR=${DIR:-ltr}"
        "DIR_CSS=${DIR_CSS:-}" "FONT_STACK=${FONT_STACK:-}" "DISCLAIMER=${DISCLAIMER:-}"
        "LOGO_URL=${LOGO_URL:-}" "LOGO_W=${LOGO_W:-}" "LOGO_H=${LOGO_H:-}"
        "BANNER_URL=${BANNER_URL:-}" "BANNER_W=${BANNER_W:-}" "BANNER_H=${BANNER_H:-}"
        "BANNER_ALT=${BANNER_ALT:-}" "BANNER_LINK=${BANNER_LINK:-}"
    )
    local pair
    for pair in "${map[@]}"; do
        printf '%s\0' "--set" "$pair"
    done
}

sig_template_path() {
    local template="$1"
    if [[ "$template" == /* ]]; then
        printf '%s' "$template"
        return
    fi
    local builtin="${APP_ROOT}/templates/signatures/${template}"
    case "$template" in
        text-only) printf '%s/text-only.txt.tpl' "${APP_ROOT}/templates/signatures" ;;
        *) printf '%s.html.tpl' "$builtin" ;;
    esac
}

sig_render_user() {
    local email="$1"
    require_email "$email"
    local domain="${email#*@}" local_part="${email%%@*}"
    sig_resolve_values "$domain" "$local_part"
    local tpl outdir out_html out_txt
    tpl="$(sig_template_path "$TEMPLATE")"
    [[ -r "$tpl" ]] || die "signature template not found: ${tpl}"
    outdir="$(sig_rendered_dir "$domain")"
    out_html="${outdir}/${local_part}.html"
    out_txt="${outdir}/${local_part}.txt"

    if ((DRY_RUN)); then
        log_info "[dry-run] render signature ${email}"
        return 0
    fi
    ensure_dir "$outdir" 0750 root:"$(web_user)"
    local -a args=()
    mapfile -t -d '' args < <(sig_render_values_args)
    # shellcheck disable=SC2016
    python3 "$(sig_py)" render "$tpl" "$out_html" --txt "$out_txt" "${args[@]}" ||
        die "failed to generate the signature for ${email}"
    chmod 0640 "$out_html" "$out_txt"
    chown root:"$(web_user)" "$out_html" "$out_txt" 2>/dev/null || true

    local size
    size="$(wc -c <"$out_html")"
    ((size > 10240)) && log_warn "signature for ${email} exceeds 10KB (${size})."
    ((size > 6144 && size <= 10240)) && log_warn "signature for ${email} is near the limit (${size} bytes)."
    log_info "signature for ${email}: ${out_html}"
}

sig_apply_all() {
    local d local_part email
    while read -r d; do
        [[ -z "$d" ]] && continue
        while read -r email; do
            [[ -z "$email" ]] && continue
            sig_render_user "$email"
        done < <(db_list_mailboxes "$d")
    done < <(db_list_domains)
}

sig_image_add() {
    local domain="$1" file="$2" kind="${3:-logo}"
    require_domain "$domain"
    [[ -r "$file" ]] || die "image not found: ${file}"
    local dims ext sha dest url_dest
    dims="$(python3 "$(sig_py)" inspect-image "$file" "$kind")" ||
        die "image rejected (type/size/dimensions)."
    local w h typ
    w="${dims%%x*}"
    h="${dims#*x}"
    h="${h%% *}"
    typ="${dims##* }"
    case "$typ" in
        png) ext=png ;; gif) ext=gif ;; jpg) ext=jpg ;;
        *) die "unsupported image type: ${typ}" ;;
    esac
    sha="$(sha256sum "$file" | cut -c1-16)"
    dest="$(sig_assets_dir "$domain")/${sha}.${ext}"
    ensure_dir "$(sig_assets_dir "$domain")" 0755 root:"$(web_user)"
    if ((DRY_RUN)); then
        log_info "[dry-run] add image ${dest}"
        return 0
    fi
    cp -f -- "$file" "$dest"
    chmod 0644 "$dest"
    if command -v exiftool >/dev/null 2>&1; then
        exiftool -all= -overwrite_original "$dest" >/dev/null 2>&1 || true
    else
        log_warn "exiftool is not available; EXIF data was not stripped from the image."
    fi
    url_dest="https://${MAIL_HOSTNAME}/sig-assets/${domain}/${sha}.${ext}"
    if [[ "$kind" == "banner" ]]; then
        sig_env_set "$(sig_profile_env "$domain")" BANNER_URL "$url_dest"
        sig_env_set "$(sig_profile_env "$domain")" BANNER_W "$w"
        sig_env_set "$(sig_profile_env "$domain")" BANNER_H "$h"
        sig_env_set "$(sig_profile_env "$domain")" BANNER_ALT "${BANNER_ALT:-banner}"
    else
        sig_env_set "$(sig_profile_env "$domain")" LOGO_URL "$url_dest"
        sig_env_set "$(sig_profile_env "$domain")" LOGO_W "$((w / 2))"
        sig_env_set "$(sig_profile_env "$domain")" LOGO_H "$((h / 2))"
    fi
    log_info "added ${kind} to domain ${domain}: ${url_dest} (${w}x${h})"
}

sig_export() {
    local email="$1" format="$2" out="$3"
    local domain="${email#*@}" local_part="${email%%@*}"
    sig_render_user "$email"
    local src_html src_txt
    src_html="$(sig_rendered_dir "$domain")/${local_part}.html"
    src_txt="$(sig_rendered_dir "$domain")/${local_part}.txt"
    ((DRY_RUN)) && {
        log_info "[dry-run] export ${email} -> ${out}"
        return 0
    }
    ensure_dir "$out" 0755 root:root
    case "$format" in
        thunderbird)
            cp -f "$src_html" "${out}/signature.html"
            ;;
        outlook)
            cp -f "$src_html" "${out}/${local_part}.htm"
            cp -f "$src_txt" "${out}/${local_part}.txt"
            ;;
        apple | html)
            cp -f "$src_html" "${out}/signature.html"
            ;;
        txt)
            cp -f "$src_txt" "${out}/signature.txt"
            ;;
        *) die "unsupported export format: ${format}" "$EX_USAGE" ;;
    esac
    cat >"${out}/README-signature.md" <<EOF

- **Thunderbird:** Settings > account identity > attach the signature from a file > choose signature.html (enable HTML).
- **Outlook (Windows):** copy ${local_part}.htm and ${local_part}.txt to %APPDATA%\Microsoft\Signatures\ then choose the signature.
- **Apple Mail / HTML:** paste the contents of signature.html into the signature preferences.
- Images are hosted on ${MAIL_HOSTNAME}; if Outlook blocks images, the text alternatives are shown.
EOF
    log_info "exported the signature to ${out} (${format})."
}

sig_server_install_footer() {
    local dst="${APP_LIBEXEC}/mailstead-footer.py"
    ensure_dir "$APP_LIBEXEC" 0755 root:root
    TPL_VARS="APP_LIB"
    render_template "${APP_ROOT}/templates/signatures/mailstead-footer.py.tpl" "$dst" 0755 root:root
}

cmd_sig_server() {
    local action="${1:-status}"
    case "$action" in
        enable)
            [[ "$(comp_get signatures)" == "server" ]] ||
                log_warn "signatures is not server; the server footer will be enabled manually."
            sig_server_install_footer
            ensure_system_user "${APP_SLUG}-filter"
            postfix_footer_enable
            state_set SIG_SERVER enabled
            log_info "server footer enabled (experimental). Check DKIM = pass after footering."
            ;;
        disable)
            postfix_footer_disable
            state_set SIG_SERVER disabled
            log_info "server footer disabled."
            ;;
        status)
            printf 'server footer state: %s\n' "$(state_get SIG_SERVER 2>/dev/null || printf disabled)"
            ;;
        *) die "usage: ${APP_CMD} sig server enable|disable|status" "$EX_USAGE" ;;
    esac
}

cmd_sig() {
    require_config
    local sub="${1:-}"
    shift || true
    case "$sub" in
        template)
            local what="${1:-list}"
            case "$what" in
                list) printf 'templates: text-only classic-html banner-html\n' ;;
                show)
                    local name="${2:-}"
                    [[ -n "$name" ]] || die "usage: ${APP_CMD} sig template show NAME" "$EX_USAGE"
                    cat -- "$(sig_template_path "$name")"
                    ;;
                *) die "unknown: ${what}" "$EX_USAGE" ;;
            esac
            ;;
        set)
            local target="" name="" title="" org="" phone="" website="" accent="" dir=""
            local logo="" banner="" banner_link="" banner_alt="" tpl="" disc=""
            target="${1:-}"
            shift || true
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --template)
                        tpl="$2"
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
                    --org)
                        org="$2"
                        shift 2
                        ;;
                    --phone)
                        phone="$2"
                        shift 2
                        ;;
                    --website)
                        website="$2"
                        shift 2
                        ;;
                    --accent)
                        accent="$2"
                        shift 2
                        ;;
                    --dir)
                        dir="$2"
                        shift 2
                        ;;
                    --logo)
                        logo="$2"
                        shift 2
                        ;;
                    --banner)
                        banner="$2"
                        shift 2
                        ;;
                    --banner-link)
                        banner_link="$2"
                        shift 2
                        ;;
                    --banner-alt)
                        banner_alt="$2"
                        shift 2
                        ;;
                    --disclaimer-file)
                        disc="$2"
                        shift 2
                        ;;
                    *) die "unknown option: $1" "$EX_USAGE" ;;
                esac
            done
            [[ -n "$target" ]] || die "usage: ${APP_CMD} sig set DOMAIN|user@d [options]" "$EX_USAGE"
            local envf
            if [[ "$target" == *@* ]]; then
                local d="${target#*@}" l="${target%%@*}"
                envf="$(sig_user_env "$d" "$l")"
            else
                require_domain "$target"
                envf="$(sig_profile_env "$target")"
            fi
            [[ -n "$name" ]] && sig_env_set "$envf" NAME "$name"
            [[ -n "$title" ]] && sig_env_set "$envf" TITLE "$title"
            [[ -n "$org" ]] && sig_env_set "$envf" ORG "$org"
            [[ -n "$phone" ]] && sig_env_set "$envf" PHONE "$phone"
            [[ -n "$website" ]] && sig_env_set "$envf" WEBSITE "$website"
            [[ -n "$accent" ]] && sig_env_set "$envf" ACCENT "$accent"
            [[ -n "$dir" ]] && sig_env_set "$envf" DIR "$dir"
            [[ -n "$tpl" ]] && sig_env_set "$envf" TEMPLATE "$tpl"
            if [[ -n "$disc" ]]; then
                [[ -r "$disc" ]] || die "disclaimer file not found: ${disc}"
                sig_env_set "$envf" DISCLAIMER "$(cat -- "$disc")"
            fi
            [[ -n "$banner_link" ]] && sig_env_set "$envf" BANNER_LINK "$banner_link"
            [[ -n "$banner_alt" ]] && sig_env_set "$envf" BANNER_ALT "$banner_alt"
            if [[ -n "$logo" && "$target" != *@* ]]; then sig_image_add "$target" "$logo" logo; fi
            if [[ -n "$banner" && "$target" != *@* ]]; then sig_image_add "$target" "$banner" banner; fi
            log_info "updated the signature file: ${envf}"
            ;;
        set-html)
            local target="${1:-}" file="${2:-}"
            [[ -n "$target" && -n "$file" ]] || die "usage: ${APP_CMD} sig set-html DOMAIN|user@d FILE.html" "$EX_USAGE"
            [[ -r "$file" ]] || die "file not found: ${file}"
            local cleaned="${APP_LIB}/cache/sig-clean.html"
            ensure_dir "${APP_LIB}/cache" 0700 root:root
            if ! python3 "$(sig_py)" sanitize "$file" "$cleaned"; then
                die "custom design rejected: it contains disallowed elements or exceeds the limit." "$EX_VERIFY"
            fi
            local d="${target#*@}"
            [[ "$target" == *@* ]] || require_domain "$target"
            local dst
            dst="$(sig_templates_dir)/${d}-custom.html.tpl"
            ensure_dir "$(sig_templates_dir)" 0755 root:root
            cp -f "$cleaned" "$dst"
            local envf
            if [[ "$target" == *@* ]]; then envf="$(sig_user_env "${target#*@}" "${target%%@*}")"; else envf="$(sig_profile_env "$target")"; fi
            sig_env_set "$envf" TEMPLATE "$dst"
            log_info "set a custom template (sanitized): ${dst}"
            ;;
        set-text)
            local target="${1:-}" file="${2:-}"
            [[ -n "$target" && -n "$file" ]] || die "usage: ${APP_CMD} sig set-text DOMAIN|user@d FILE.txt" "$EX_USAGE"
            [[ -r "$file" ]] || die "file not found: ${file}"
            local envf
            if [[ "$target" == *@* ]]; then envf="$(sig_user_env "${target#*@}" "${target%%@*}")"; else
                require_domain "$target"
                envf="$(sig_profile_env "$target")"
            fi
            sig_env_set "$envf" TEMPLATE "text-only"
            sig_env_set "$envf" DISCLAIMER "$(cat -- "$file")"
            log_info "set a text signature."
            ;;
        image)
            local action="${1:-add}"
            shift || true
            case "$action" in
                add)
                    local domain="${1:-}" file="${2:-}" kind="logo"
                    shift 2 || true
                    while [[ $# -gt 0 ]]; do
                        case "$1" in --kind)
                            kind="$2"
                            shift 2
                            ;;
                        *) shift ;; esac
                    done
                    [[ -n "$domain" && -n "$file" ]] || die "usage: ${APP_CMD} sig image add DOMAIN FILE [--kind logo|banner]" "$EX_USAGE"
                    sig_image_add "$domain" "$file" "$kind"
                    ;;
                *) die "unknown: ${action}" "$EX_USAGE" ;;
            esac
            ;;
        preview)
            local target="${1:-}"
            [[ -n "$target" ]] || die "usage: ${APP_CMD} sig preview user@d" "$EX_USAGE"
            require_email "$target"
            sig_render_user "$target"
            local domain="${target#*@}" local_part="${target%%@*}"
            local tmp="/tmp/${APP_SLUG}-sig-${local_part}.html"
            cp -f "$(sig_rendered_dir "$domain")/${local_part}.html" "$tmp"
            log_info "preview: ${tmp}"
            log_info "protected page link: https://${MAIL_HOSTNAME}/sig/${domain}/${local_part}.html"
            sig_quality_checks "$domain" "$local_part"
            ;;
        apply)
            local target="${1:-}"
            if [[ "$target" == "--all" || -z "$target" ]]; then
                sig_apply_all
            elif [[ "$target" == *@* ]]; then
                sig_render_user "$target"
            else
                require_domain "$target"
                local email
                while read -r email; do [[ -n "$email" ]] && sig_render_user "$email"; done < <(db_list_mailboxes "$target")
            fi
            log_info "regenerated the signatures (idempotent)."
            ;;
        export)
            local target="${1:-}"
            shift || true
            local format="html" out="/tmp/${APP_SLUG}-export"
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --format)
                        format="$2"
                        shift 2
                        ;;
                    --out)
                        out="$2"
                        shift 2
                        ;;
                    *) die "unknown option: $1" "$EX_USAGE" ;;
                esac
            done
            require_email "$target"
            sig_export "$target" "$format" "$out"
            ;;
        remove)
            local target="${1:-}"
            [[ -n "$target" ]] || die "usage: ${APP_CMD} sig remove user@d|DOMAIN" "$EX_USAGE"
            if [[ "$target" == *@* ]]; then
                local d="${target#*@}" l="${target%%@*}"
                if ((DRY_RUN)); then log_info "[dry-run] remove sig ${target}"; else
                    rm -f -- "$(sig_user_env "$d" "$l")" "$(sig_rendered_dir "$d")/${l}.html" "$(sig_rendered_dir "$d")/${l}.txt"
                fi
            else
                require_domain "$target"
                backup_file "$(sig_domain_dir "$target")"
                if ((DRY_RUN)); then log_info "[dry-run] remove domain sig ${target}"; else
                    rm -rf -- "$(sig_domain_dir "$target")" "$(sig_rendered_dir "$target")" "$(sig_assets_dir "$target")"
                fi
            fi
            log_info "removed the signature for ${target}."
            ;;
        server)
            cmd_sig_server "$@"
            ;;
        *) die "usage: ${APP_CMD} sig <template|set|set-html|set-text|image|preview|apply|export|remove|server>" "$EX_USAGE" ;;
    esac
}

sig_quality_checks() {
    local domain="$1" local_part="$2"
    local html
    html="$(sig_rendered_dir "$domain")/${local_part}.html"
    [[ -r "$html" ]] || return 0
    local text_len links
    text_len="$(python3 "$(sig_py)" totext "$html" | tr -d '[:space:]' | wc -c)"
    links="$(grep -o 'href=' "$html" | wc -l)"
    if ((text_len < 20)); then log_warn "signature for ${local_part} is nearly text-free (spam warning)."; fi
    if ((links > 5)); then log_warn "the signature for ${local_part} has more than 5 links."; fi
    if grep -qE 'bit\.ly|t\.co|goo\.gl|tinyurl' "$html"; then log_warn "short links in the signature for ${local_part}."; fi
}
