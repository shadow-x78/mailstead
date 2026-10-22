protocols = imap lmtp sieve
postmaster_address = postmaster@@POSTMASTER_DOMAIN@@
mail_home = /var/vmail/%d/%n
log_path = /var/log/dovecot.log
info_log_path = /var/log/dovecot.log
auth_verbose = no
mail_debug = no
mailbox_list_index = yes