server {
    listen 80;
    listen [::]:80;
    server_name mta-sts.@@DOMAIN@@;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type text/plain;
    }
    location / { return 301 https://$host$request_uri; }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name mta-sts.@@DOMAIN@@;

    ssl_certificate     @@WEB_CERT_FULLCHAIN@@;
    ssl_certificate_key @@WEB_CERT_KEY@@;

    root @@APP_LIB@@/web/mta-sts/@@DOMAIN@@;

    location = /.well-known/mta-sts.txt {
        default_type text/plain;
        add_header Cache-Control "public, max-age=3600";
        try_files $uri =404;
    }
    location / { return 404; }
}