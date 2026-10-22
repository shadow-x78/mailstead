#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Database Abstraction Layer
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

# shellcheck shell=bash

MAIL_DB="mailserver"

db_backend() {
    if [[ "$(comp_get dashboard)" == "postfixadmin" ]]; then
        printf 'postfixadmin'
    else
        printf 'sql'
    fi
}

sql_quote() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\'/\'\'}"
    printf '%s' "$s"
}

db_sql_root() {
    local sql="$1"
    if ((DRY_RUN)); then
        log_info "[dry-run] mysql -e <sql>"
        return 0
    fi
    command -v mysql >/dev/null 2>&1 ||
        die "the mysql client is not installed; MariaDB is not present." "$EX_ERR"
    mysql --protocol=socket -N -B -e "$sql"
}

db_sql_root_db() {
    local db="$1" sql="$2"
    if ((DRY_RUN)); then
        log_info "[dry-run] mysql ${db} -e <sql>"
        return 0
    fi
    command -v mysql >/dev/null 2>&1 ||
        die "the mysql client is not installed; MariaDB is not present." "$EX_ERR"
    mysql --protocol=socket -N -B -D "$db" -e "$sql"
}

db_require() {
    ((DRY_RUN)) && return 0
    command -v mysql >/dev/null 2>&1 ||
        die "the mysql client is not installed; MariaDB is not present." "$EX_ERR"
    mysql --protocol=socket -N -B -e 'SELECT 1' >/dev/null 2>&1 ||
        die "cannot connect to MariaDB; is the database running?" "$EX_ERR"
}

db_query() {
    local db="$1" sql="$2"
    if ((DRY_RUN)); then
        return 0
    fi
    mysql --protocol=socket -N -B -D "$db" -e "$sql" 2>/dev/null
}

pfa_cli_path() { printf '%s/scripts/postfixadmin-cli' "$(pfa_dir 2>/dev/null || printf '/var/www/postfixadmin')"; }

pfa_cli() {
    local cli
    cli="$(pfa_cli_path)"
    [[ -x "$cli" ]] || die "postfixadmin-cli not found: ${cli}"
    run_secret php "$cli" "$@"
}

db_hash_password() {
    local pw="$1"
    if ((DRY_RUN)); then
        printf '{BLF-CRYPT}$2b$05$DRYRUNHASHDRYRUNHASHDRYRUNHASHDRYRUNHASHDRYRUNHA'
        return 0
    fi
    doveadm pw -s BLF-CRYPT -p "$pw"
}

db_configure() {
    local mailro_pw mailpw_pw
    mailro_pw="$(secret_ensure db_mailro)"
    mailpw_pw="$(secret_ensure db_mailpw)"

    if ((DRY_RUN)); then
        log_info "[dry-run] db_configure"
        return 0
    fi

    _db_mariadb_secure

    db_sql_root "CREATE DATABASE IF NOT EXISTS ${MAIL_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    db_sql_root "CREATE USER IF NOT EXISTS 'mailro'@'127.0.0.1' IDENTIFIED BY '$(sql_quote "$mailro_pw")';"
    db_sql_root "ALTER USER 'mailro'@'127.0.0.1' IDENTIFIED BY '$(sql_quote "$mailro_pw")';"
    db_sql_root "GRANT SELECT ON ${MAIL_DB}.* TO 'mailro'@'127.0.0.1';"
    db_sql_root "CREATE USER IF NOT EXISTS 'mailpw'@'127.0.0.1' IDENTIFIED BY '$(sql_quote "$mailpw_pw")';"
    db_sql_root "ALTER USER 'mailpw'@'127.0.0.1' IDENTIFIED BY '$(sql_quote "$mailpw_pw")';"
    db_sql_root "GRANT SELECT ON ${MAIL_DB}.mailbox TO 'mailpw'@'127.0.0.1';"
    db_sql_root "GRANT UPDATE (password, modified) ON ${MAIL_DB}.mailbox TO 'mailpw'@'127.0.0.1';"
    db_sql_root "FLUSH PRIVILEGES;"

    if [[ "$(db_backend)" == "sql" ]]; then
        db_sql_root_db "$MAIL_DB" "$(cat -- "${APP_ROOT}/templates/sql/schema.sql")"
    fi
    state_set DB_BACKEND "$(db_backend)"
}

_db_mariadb_secure() {
    local conf="/etc/mysql/mariadb.conf.d/99-${APP_SLUG}.cnf"
    [[ -d /etc/mysql/mariadb.conf.d ]] || conf="/etc/my.cnf.d/99-${APP_SLUG}.cnf"
    if [[ ! -f "$conf" ]]; then
        backup_file "$conf"
        ensure_dir "$(dirname -- "$conf")"
        cat >"$conf" <<EOF
[mysqld]
bind-address = 127.0.0.1
skip-name-resolve = 1
EOF
    fi
}

db_add_domain() {
    local domain="$1" desc="${2:-}"
    require_domain "$domain"
    if [[ "$(db_backend)" == "postfixadmin" ]]; then
        pfa_cli domain add "$domain" --description "$desc" --active 1
        [[ $? -eq 0 || $(db_domain_exists "$domain") == 1 ]] || die "failed to create domain via postfixadmin-cli"
        return 0
    fi
    db_sql_root "INSERT INTO ${MAIL_DB}.domain
        (domain,description,aliases,mailboxes,maxquota,quota,transport,backupmx,created,modified,active)
        VALUES ('$(sql_quote "$domain")','$(sql_quote "$desc")',0,0,0,0,'virtual',0,NOW(),NOW(),1)
        ON DUPLICATE KEY UPDATE active=1, modified=NOW();"
}

db_del_domain() {
    local domain="$1"
    require_domain "$domain"
    if [[ "$(db_backend)" == "postfixadmin" ]]; then
        pfa_cli domain delete "$domain" || true
        return 0
    fi
    db_sql_root "DELETE FROM ${MAIL_DB}.mailbox WHERE domain='$(sql_quote "$domain")';
                 DELETE FROM ${MAIL_DB}.alias WHERE domain='$(sql_quote "$domain")';
                 DELETE FROM ${MAIL_DB}.domain WHERE domain='$(sql_quote "$domain")';"
}

db_domain_exists() {
    local domain="$1" n
    n="$(db_query "$MAIL_DB" "SELECT COUNT(*) FROM domain WHERE domain='$(sql_quote "$domain")' AND active='1';")"
    [[ "${n:-0}" -ge 1 ]]
}

db_list_domains() {
    db_query "$MAIL_DB" "SELECT domain FROM domain WHERE active='1' ORDER BY domain;"
}

db_add_mailbox() {
    local email="$1" pw="$2" quota_bytes="${3:-0}" name="${4:-}"
    require_email "$email"
    local local_part="${email%%@*}" domain="${email#*@}" hash
    hash="$(db_hash_password "$pw")"

    if [[ "$(db_backend)" == "postfixadmin" ]]; then
        pfa_cli mailbox add "$email" --password "$pw" --password2 "$pw" \
            --name "$name" --quota "$((quota_bytes / 1048576))" --active 1
        return 0
    fi
    db_sql_root "INSERT INTO ${MAIL_DB}.mailbox
            (username,password,name,maildir,quota,local_part,domain,created,modified,active)
        VALUES
            ('$(sql_quote "$email")','$(sql_quote "$hash")','$(sql_quote "$name")','',${quota_bytes},'$(sql_quote "$local_part")','$(sql_quote "$domain")',NOW(),NOW(),1)
        ON DUPLICATE KEY UPDATE password=VALUES(password), name=VALUES(name), quota=VALUES(quota), modified=NOW(), active=1;
        INSERT INTO ${MAIL_DB}.alias (address,goto,domain,created,modified,active)
        VALUES ('$(sql_quote "$email")','$(sql_quote "$email")','$(sql_quote "$domain")',NOW(),NOW(),1)
        ON DUPLICATE KEY UPDATE goto=VALUES(goto), modified=NOW(), active=1;"
}

db_del_mailbox() {
    local email="$1"
    require_email "$email"
    if [[ "$(db_backend)" == "postfixadmin" ]]; then
        pfa_cli mailbox delete "$email" || true
        return 0
    fi
    db_sql_root "DELETE FROM ${MAIL_DB}.mailbox WHERE username='$(sql_quote "$email")';
                 DELETE FROM ${MAIL_DB}.alias WHERE address='$(sql_quote "$email")';"
}

db_set_password() {
    local email="$1" pw="$2" hash
    require_email "$email"
    if [[ "$(db_backend)" == "postfixadmin" ]]; then
        pfa_cli mailbox update "$email" --password "$pw" --password2 "$pw"
        return 0
    fi
    hash="$(db_hash_password "$pw")"
    db_sql_root "UPDATE ${MAIL_DB}.mailbox SET password='$(sql_quote "$hash")', modified=NOW() WHERE username='$(sql_quote "$email")';"
}

db_list_mailboxes() {
    local domain="${1:-}"
    if [[ -n "$domain" ]]; then
        db_query "$MAIL_DB" "SELECT username FROM mailbox WHERE domain='$(sql_quote "$domain")' AND active='1' ORDER BY username;"
    else
        db_query "$MAIL_DB" "SELECT username FROM mailbox WHERE active='1' ORDER BY username;"
    fi
}

db_mailbox_exists() {
    local email="$1" n
    n="$(db_query "$MAIL_DB" "SELECT COUNT(*) FROM mailbox WHERE username='$(sql_quote "$email")' AND active='1';")"
    [[ "${n:-0}" -ge 1 ]]
}

db_add_alias() {
    local address="$1" goto="$2"
    require_email "$address"
    local domain="${address#*@}"
    if [[ "$(db_backend)" == "postfixadmin" ]]; then
        pfa_cli alias add "$address" --goto "$goto" --active 1
        return 0
    fi
    db_sql_root "INSERT INTO ${MAIL_DB}.alias (address,goto,domain,created,modified,active)
        VALUES ('$(sql_quote "$address")','$(sql_quote "$goto")','$(sql_quote "$domain")',NOW(),NOW(),1)
        ON DUPLICATE KEY UPDATE goto=VALUES(goto), modified=NOW(), active=1;"
}

db_del_alias() {
    local address="$1"
    if [[ "$(db_backend)" == "postfixadmin" ]]; then
        pfa_cli alias delete "$address" || true
        return 0
    fi
    db_sql_root "DELETE FROM ${MAIL_DB}.alias WHERE address='$(sql_quote "$address")';"
}

db_list_aliases() {
    local domain="${1:-}"
    if [[ -n "$domain" ]]; then
        db_query "$MAIL_DB" "SELECT address,goto FROM alias WHERE domain='$(sql_quote "$domain")' AND active='1' ORDER BY address;"
    else
        db_query "$MAIL_DB" "SELECT address,goto FROM alias WHERE active='1' ORDER BY address;"
    fi
}

db_add_admin() {
    local email="$1" pw="$2"
    require_email "$email"
    if [[ "$(db_backend)" != "postfixadmin" ]]; then
        return 0
    fi
    pfa_cli admin add "$email" --password "$pw" --password2 "$pw" --superadmin 1 --active 1
}
