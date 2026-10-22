#!/usr/bin/env bash

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

        *) printf '%s' "$logical" ;;
    esac
}

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

dedupe_lines() {
    awk '!seen[$0]++'
}


