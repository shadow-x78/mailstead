# ─────────────────────────────────────────────
# Mailstead - Nginx ACME Challenge Vhost
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

server {
    listen 80;
    listen [::]:80;
    server_name @@ALL_HOSTNAMES@@;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type text/plain;
        try_files $uri =404;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
