# 10-ssl.conf.tpl - TLS. Managed by Mailstead.
ssl = required
ssl_cert = <@@TLS_CERT_FILE@@
ssl_key = <@@TLS_KEY_FILE@@
ssl_min_protocol = TLSv1.2
ssl_prefer_server_ciphers = no
ssl_cipher_list = ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384