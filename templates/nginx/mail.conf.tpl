# mail.conf.tpl - Roundcube (webmail) vhost + hosted signature assets. Managed.
server {
    listen 80;
    listen [::]:80;
    server_name @@MAIL_HOSTNAME@@;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type text/plain;
    }
    location / { return 301 https://$host$request_uri; }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name @@MAIL_HOSTNAME@@;

    ssl_certificate     @@TLS_CERT_FILE@@;
    ssl_certificate_key @@TLS_KEY_FILE@@;

    root @@ROUNDCUBE_DOCROOT@@;
    index index.php index.html;

    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
    add_header Strict-Transport-Security "max-age=31536000" always;

    client_max_body_size 25m;

    # Block access to sensitive Roundcube paths.
    location ~ ^/(config|temp|logs|bin|SQL|vendor|composer\.|README|INSTALL|LICENSE|CHANGELOG|UPGRADING|\.git) {
        return 404;
    }
    location ~ /\.(?!well-known) { return 404; }

    # Hosted signature assets (read-only, immutable filenames).
    location ^~ /sig-assets/ {
        alias @@APP_LIB@@/signatures/assets/;
        autoindex off;
        location ~ ^/sig-assets/[a-z0-9.-]+/[a-f0-9]{16}\.(png|jpe?g|gif)$ {
            expires 30d;
            add_header Cache-Control "public, immutable";
            add_header X-Content-Type-Options nosniff;
            try_files $uri =404;
        }
        location ~ ^/sig-assets/ { return 404; }
    }

    # Signature preview/copy pages.
    location ^~ /sig/ {
        alias @@APP_LIB@@/signatures/rendered/;
        autoindex off;
        try_files $uri =404;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ ^/index\.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass unix:@@PHP_SOCKET@@;
        fastcgi_read_timeout 300;
    }
    location ~ \.php$ {
        return 404;
    }
}