#!/usr/bin/env bash
# lib/distro/pkgmap.sh - logical package name -> real package names.
#
# Naming differences between Debian/Ubuntu and Fedora/RHEL-family are isolated
# here. Arch and openSUSE are intentionally absent (unsupported in v1).
# Verify each cell on a VM and record the result with a "# verified on" note.

# pkgmap_get LOGICAL... -> prints space-separated real package names.
pkgmap_get() {
    local logical fam="${DISTRO_FAMILY:-debian}" out="" name
    for logical in "$@"; do
        name="$(_pkgmap_one "$logical" "$fam")"
        out+=" ${name}"
    done
    printf '%s' "${out# }"
}

_pkgmap_one() {
    local logical="$1" fam="$2"
    case "${fam}:${logical}" in
        # ---- Debian / Ubuntu ----
        debian:postfix) printf 'postfix postfix-mysql postfix-pcre' ;;
        debian:dovecot) printf 'dovecot-core dovecot-imapd dovecot-lmtpd dovecot-mysql dovecot-sieve dovecot-managesieved' ;;
        debian:opendkim) printf 'opendkim opendkim-tools' ;;
        debian:rspamd) printf 'rspamd' ;;
        debian:kv) printf 'redis-server' ;;
        debian:mariadb) printf 'mariadb-server' ;;
        debian:nginx) printf 'nginx' ;;
        debian:php-fpm) printf 'php-fpm php-mysql php-mbstring php-xml php-intl php-zip php-gd php-curl' ;;
        debian:php-imap) printf 'php-imap' ;;
        debian:certbot) printf 'certbot' ;;
        debian:fail2ban) printf 'fail2ban' ;;
        debian:unbound) printf 'unbound' ;;
        debian:dig) printf 'dnsutils' ;;
        debian:swaks) printf 'swaks' ;;
        debian:openssl) printf 'openssl' ;;
        debian:curl) printf 'curl' ;;
        debian:xmllint) printf 'libxml2-utils' ;;
        debian:python3) printf 'python3' ;;
        debian:exiftool) printf 'libimage-exiftool-perl' ;;
        debian:ca-certificates) printf 'ca-certificates' ;;
        debian:ssl-cert) printf 'ssl-cert' ;;
        debian:logrotate) printf 'logrotate' ;;
        debian:pflogsumm) printf 'pflogsumm' ;;
        debian:unattended-upgrades) printf 'unattended-upgrades' ;;
        debian:policycoreutils) printf '' ;;

        # ---- Fedora / RHEL-family ----
        rhel:postfix) printf 'postfix postfix-mysql postfix-pcre' ;;
        rhel:dovecot) printf 'dovecot dovecot-mysql dovecot-pigeonhole' ;;
        rhel:opendkim) printf 'opendkim opendkim-tools' ;;
        rhel:rspamd) printf 'rspamd' ;;
        rhel:kv) printf 'redis' ;;
        rhel:mariadb) printf 'mariadb-server' ;;
        rhel:nginx) printf 'nginx' ;;
        rhel:php-fpm) printf 'php-fpm php-mysqlnd php-mbstring php-xml php-intl php-zip php-gd php-json' ;;
        rhel:php-imap) printf '' ;;
        rhel:certbot) printf 'certbot' ;;
        rhel:fail2ban) printf 'fail2ban' ;;
        rhel:unbound) printf 'unbound' ;;
        rhel:dig) printf 'bind-utils' ;;
        rhel:swaks) printf 'swaks' ;;
        rhel:openssl) printf 'openssl' ;;
        rhel:curl) printf 'curl' ;;
        rhel:xmllint) printf 'libxml2' ;;
        rhel:python3) printf 'python3' ;;
        rhel:exiftool) printf 'perl-Image-ExifTool' ;;
        rhel:ca-certificates) printf 'ca-certificates' ;;
        rhel:ssl-cert) printf '' ;;
        rhel:logrotate) printf 'logrotate' ;;
        rhel:pflogsumm) printf 'postfix-perl-scripts' ;;
        rhel:unattended-upgrades) printf 'dnf-automatic' ;;
        rhel:policycoreutils) printf 'policycoreutils-python-utils' ;;

        # Unknown logical name: treat it as a real package name (passthrough).
        *) printf '%s' "$logical" ;;
    esac
}

# pkgmap_expand LOGICAL... -> prints one real package name per line.
# Safe under the global IFS=$'\n\t' (never relies on space splitting).
pkgmap_expand() {
    local logical r
    local -a arr=()
    for logical in "$@"; do
        r="$(pkgmap_get "$logical")"
        [[ -z "$r" ]] && continue
        arr=()
        IFS=' ' read -r -a arr <<<"$r"
        printf '%s\n' "${arr[@]}"
    done
}

# dedupe_lines: read newline-separated input on stdin, print unique lines.
dedupe_lines() {
    awk '!seen[$0]++'
}

# Logical package names that may be missing on some releases; pkg_install
# skips them with a warning instead of failing the whole phase.
PKG_OPTIONAL=(php-imap xmllint exiftool pflogsumm swaks unattended-upgrades)

pkg_is_optional() {
    local logical="$1" o
    for o in "${PKG_OPTIONAL[@]}"; do
        [[ "$o" == "$logical" ]] && return 0
    done
    return 1
}
