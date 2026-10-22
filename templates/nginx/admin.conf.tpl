# admin.conf.tpl - PostfixAdmin dashboard + Rspamd WebUI proxy (gui mode). Managed.
server {
    listen 80;
    listen [::]:80;
    server_name @@ADMIN_HOSTNAME@@;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type text/plain;
    }
    location / { return 301 https://$host$request_uri; }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name @@ADMIN_HOSTNAME@@;

    ssl_certificate     @@TLS_CERT_FILE@@;
    ssl_certificate_key @@TLS_KEY_FILE@@;

    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
    add_header Strict-Transport-Security "max-age=31536000" always;

@@ADMIN_ALLOW_IP_BLOCK@@

    root @@PFA_DOCROOT@@;
    index index.php;

    client_max_body_size 10m;

    # Never expose the setup script once configured.
    location = /setup.php { return 404; }

    # Rspamd WebUI behind basic auth (proxy to loopback controller).
    location /rspamd/ {
        proxy_pass http://127.0.0.1:11334/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        auth_basic "Rspamd";
        auth_basic_user_file /etc/nginx/.htpasswd-rspamd;
    }

    location ~ ^/(config\.local|config)\.php$ { return 404; }
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass unix:@@PHP_SOCKET@@;
    }

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
}