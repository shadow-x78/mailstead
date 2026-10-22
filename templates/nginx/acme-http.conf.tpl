# acme-http.conf.tpl - HTTP-only bootstrap vhost for ACME (P04), then redirects.
# Managed by Mailstead.
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