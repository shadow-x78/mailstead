#!/usr/bin/env bash
# lib/distro/detect.sh - detect the running distribution and family.
#
# Sets: DISTRO_ID, DISTRO_VERSION_ID, DISTRO_FAMILY, DISTRO_LIKE, PKG_MGR
# Rejects unsupported distributions (plan-3 section C) with exit code 3.

# distro_detect [--force-unsupported]
# Returns 0 when a supported Tier-1 distribution is detected and the family
# module has been loaded. Exits 3 for explicitly unsupported distributions.
distro_detect() {
    local force="${1:-}" id="" id_like="" version="" pr_name=""
    local osrel="${OS_RELEASE_FILE:-/etc/os-release}"
    if [[ -r "$osrel" ]]; then
        # shellcheck disable=SC1090
        . "$osrel"
        id="${ID:-}"
        id_like="${ID_LIKE:-}"
        version="${VERSION_ID:-}"
        pr_name="${PRETTY_NAME:-${NAME:-$id}}"
    fi
    DISTRO_ID="${id:-unknown}"
    DISTRO_LIKE="${id_like:-}"
    DISTRO_VERSION_ID="${version:-unknown}"
    [[ -z "$pr_name" ]] && pr_name="$DISTRO_ID"

    # Build the set of family hints from ID and ID_LIKE.
    local hints
    hints=" ${DISTRO_ID,,} ${DISTRO_LIKE,,} "

    case "$hints" in
        *" arch "* | *" manjaro "* | *" endeavouros "*)
            _unsupported_distro "$pr_name"
            ;;
        *" opensuse "* | *" opensuse-leap "* | *" opensuse-tumbleweed "* | *" sles "* | *" suse "* | *" opensuse-microos "*)
            _unsupported_distro "$pr_name"
            ;;
        *" alpine "* | *" void "* | *" gentoo "*)
            _unsupported_distro "$pr_name"
            ;;
    esac

    case "$hints" in
        *" debian "* | *" ubuntu "*)
            DISTRO_FAMILY="debian"
            PKG_MGR="apt"
            ;;
        *" fedora "* | *" rhel "* | *" centos "* | *" almalinux "* | *" rocky "* | *" ol "*)
            DISTRO_FAMILY="rhel"
            PKG_MGR="dnf"
            ;;
        *)
            if [[ "$force" == "--force-unsupported" ]]; then
                log_warn "unknown distro (${pr_name}); continuing with --force-unsupported has no official support."
                DISTRO_FAMILY="debian"
                PKG_MGR="apt"
            else
                _unsupported_distro "$pr_name"
            fi
            ;;
    esac

    # MAILSTEAD_ALLOW_NO_SYSTEMD=1 is only for unit tests on non-systemd hosts.
    if [[ "${MAILSTEAD_ALLOW_NO_SYSTEMD:-0}" != "1" ]]; then
        if ! command -v systemctl >/dev/null 2>&1 || [[ ! -d /run/systemd/system ]]; then
            die "this system does not run systemd; not supported." "$EX_UNSUPPORTED"
        fi
    fi

    export DISTRO_ID DISTRO_LIKE DISTRO_VERSION_ID DISTRO_FAMILY PKG_MGR
    log_info "distro: ${pr_name} (family=${DISTRO_FAMILY}, pkg=${PKG_MGR})"
    return 0
}

_unsupported_distro() {
    local pr_name="$1"
    die "your distro (${pr_name}) is not supported in the first release (v1). Supported: Debian/Ubuntu and Fedora/RHEL-family." "$EX_UNSUPPORTED"
}

# distro_load_family: source the family abstraction module.
distro_load_family() {
    local fam="${DISTRO_FAMILY:-}"
    [[ -n "$fam" ]] || die "the family has not been detected yet; run distro_detect first."
    local mod="${APP_ROOT}/lib/distro/${fam}.sh"
    [[ -r "$mod" ]] || die "family module not found: ${mod}"
    # shellcheck disable=SC1090
    . "$mod"
}

# distro_load_pkgmap: source the package map.
distro_load_pkgmap() {
    local mod="${APP_ROOT}/lib/distro/pkgmap.sh"
    [[ -r "$mod" ]] || die "package map not found: ${mod}"
    # shellcheck disable=SC1090
    . "$mod"
}
