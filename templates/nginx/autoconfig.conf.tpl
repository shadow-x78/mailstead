# autoconfig.conf.tpl - Thunderbird autoconfig + Outlook Autodiscover (plan-3 E).
# Managed by Mailstead. One file per domain.
server {
    listen 80;
    listen [::]:80;
    server_name autoconfig.@@DOMAIN@@ autodiscover.@@DOMAIN@@;

    location ^~ /.well-known/acme-challenge/ { root /var/www/letsencrypt; default_type text/plain; }
    location = /mail/config-v1.1.xml { root @@APP_LIB@@/web/autoconfig/@@DOMAIN@@; default_type text/xml; }
    location ~* ^/autodiscover/autodiscover\.xml$ { return 302 https://autodiscover.@@DOMAIN@@$request_uri; }
    location / { return 301 https://$host$request_uri; }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name autoconfig.@@DOMAIN@@ autodiscover.@@DOMAIN@@;

    ssl_certificate     @@WEB_CERT_FULLCHAIN@@;
    ssl_certificate_key @@WEB_CERT_KEY@@;

    root @@APP_LIB@@/web/autoconfig/@@DOMAIN@@;

    location = /mail/config-v1.1.xml {
        default_type text/xml;
        add_header Cache-Control "public, max-age=3600";
        try_files $uri =404;
    }

    location ~* ^/autodiscover/autodiscover\.xml$ {
        limit_req zone=autodiscover burst=10 nodelay;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME @@APP_OPT@@/web/autodiscover.php;
        fastcgi_pass unix:@@PHP_SOCKET@@;
    }

    location / { return 404; }
}