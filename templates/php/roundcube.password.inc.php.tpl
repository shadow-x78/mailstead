<?php
// ─────────────────────────────────────────────
// Mailstead - Roundcube Password Policy
// https://github.com/shadow-x78/mailstead
// ─────────────────────────────────────────────

$config['password_driver'] = 'sql';
$config['password_db_dsn'] = 'mysql://mailpw:@@DB_MAILPW_PW@@@127.0.0.1/mailserver';
$config['password_algorithm'] = 'dovecot';
$config['password_dovecotpw'] = '/usr/bin/doveadm pw -s BLF-CRYPT';
$config['password_dovecotpw_method'] = 'BLF-CRYPT';
$config['password_dovecotpw_with_method'] = true;
$config['password_query'] = "UPDATE mailbox SET password=%P, modified=NOW() WHERE username=%u";
