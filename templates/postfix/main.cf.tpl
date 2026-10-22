# ─────────────────────────────────────────────
# Mailstead - Postfix Main Configuration
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

myhostname = @@MAIL_HOSTNAME@@
mydomain = @@PRIMARY_DOMAIN@@
myorigin = /etc/mailname
mydestination = $myhostname, localhost.$mydomain, localhost
mynetworks = 127.0.0.0/8 [::1]/128
inet_interfaces = all
inet_protocols = @@INET_PROTOCOLS@@
smtpd_banner = $myhostname ESMTP
biff = no
append_dot_mydomain = no
recipient_delimiter = +
message_size_limit = 52428800
mailbox_size_limit = 0
disable_vrfy_command = yes
smtpd_helo_required = yes
smtpd_delay_reject = yes
maximal_queue_lifetime = 3d
bounce_queue_lifetime = 2d
compatibility_level = @@POSTFIX_COMPAT_LEVEL@@

maillog_file = /var/log/mail.log

@@POSTFIX_MAPS_BLOCK@@

milter_protocol = 6
milter_default_action = accept
@@POSTFIX_MILTERS_BLOCK@@

smtpd_tls_cert_file = @@TLS_CERT_FILE@@
smtpd_tls_key_file = @@TLS_KEY_FILE@@
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes
smtpd_tls_protocols = @@POSTFIX_TLS_PROTOCOLS@@
smtpd_tls_mandatory_protocols = @@POSTFIX_TLS_PROTOCOLS@@
smtpd_tls_ciphers = medium
smtpd_tls_mandatory_ciphers = medium
tls_preempt_cipherlist = no
smtpd_tls_received_header = yes
smtpd_tls_loglevel = 1
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache

smtp_tls_security_level = @@SMTP_TLS_LEVEL@@
smtp_tls_protocols = @@POSTFIX_TLS_PROTOCOLS@@
smtp_tls_mandatory_protocols = @@POSTFIX_TLS_PROTOCOLS@@
smtp_tls_ciphers = medium
smtp_tls_loglevel = 1
smtp_tls_note_starttls_offer = yes
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache
smtp_helo_name = $myhostname
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt

smtpd_helo_restrictions = permit_mynetworks, reject_invalid_helo_hostname, reject_non_fqdn_helo_hostname
smtpd_sender_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_sender, reject_unknown_sender_domain
smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, defer_unauth_destination
smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_recipient, reject_unknown_recipient_domain, reject_unauth_destination
smtpd_data_restrictions = reject_unauth_pipelining

smtpd_client_connection_rate_limit = 30
smtpd_client_message_rate_limit = 60
anvil_rate_time_unit = 60s

transport_maps = hash:/etc/postfix/transport
slow_destination_concurrency_limit = 2
slow_destination_recipient_limit = 20
