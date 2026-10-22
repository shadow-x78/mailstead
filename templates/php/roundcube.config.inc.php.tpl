<?php
// ─────────────────────────────────────────────
// Mailstead - Roundcube Configuration
// https://github.com/shadow-x78/mailstead
// ─────────────────────────────────────────────

$config['db_dsnw'] = 'mysql://roundcube:@@DB_RC_PW@@@127.0.0.1/roundcube';
$config['imap_host'] = 'ssl://@@MAIL_HOSTNAME@@:993';
$config['smtp_host'] = 'tls://@@MAIL_HOSTNAME@@:587';
$config['smtp_user'] = '%u';
$config['smtp_pass'] = '%p';
$config['smtp_conn_options'] = ['ssl' => ['verify_peer' => true, 'verify_peer_name' => true, 'peer_name' => '@@MAIL_HOSTNAME@@']];
$config['imap_conn_options'] = ['ssl' => ['verify_peer' => true, 'verify_peer_name' => true, 'peer_name' => '@@MAIL_HOSTNAME@@']];
$config['des_key'] = '@@RC_DES_KEY@@';
$config['product_name'] = 'Webmail';
$config['plugins'] = @@RC_PLUGINS@@;
$config['use_https'] = true;
$config['session_lifetime'] = 30;
$config['login_autocomplete'] = 0;
$config['enable_installer'] = false;
$config['managesieve_host'] = 'tls://@@MAIL_HOSTNAME@@';
$config['managesieve_port'] = 4190;
$config['skin'] = 'elastic';
