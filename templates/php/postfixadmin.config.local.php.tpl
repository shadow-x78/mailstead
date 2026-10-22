<?php
$CONF['configured'] = true;
$CONF['database_type'] = 'mysqli';
$CONF['database_host'] = '127.0.0.1';
$CONF['database_user'] = 'postfixadmin';
$CONF['database_password'] = '@@DB_PFA_PW@@';
$CONF['database_name'] = 'mailserver';
$CONF['encrypt'] = 'dovecot:BLF-CRYPT';
$CONF['dovecotpw'] = '/usr/bin/doveadm pw';
$CONF['default_language'] = 'en';
$CONF['domain_path'] = 'NO';
$CONF['domain_in_mailbox'] = 'NO';
$CONF['emailcheck_resolve_domain'] = 'NO';
$CONF['setup_password'] = '@@SETUP_HASH@@';
$CONF['admin_email'] = '@@ADMIN_EMAIL@@';