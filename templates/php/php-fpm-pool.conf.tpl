; ─────────────────────────────────────────────
; Mailstead - PHP-FPM Pool Configuration
; https://github.com/shadow-x78/mailstead
; ─────────────────────────────────────────────

; Managed by Mailstead. Do not edit the vendor default pool.

[@@APP_SLUG@@]
user = @@WEB_USER@@
group = @@WEB_USER@@
listen = @@PHP_SOCKET@@
listen.owner = @@WEB_USER@@
listen.group = @@WEB_USER@@
listen.mode = 0660

pm = ondemand
pm.max_children = 20
pm.process_idle_timeout = 10s
pm.max_requests = 500

; Security hardening for web apps hosted here.
php_admin_value[expose_php] = Off
php_admin_value[upload_max_filesize] = 25M
php_admin_value[post_max_size] = 26M
php_admin_value[max_execution_time] = 300
php_admin_value[memory_limit] = 256M
php_admin_flag[log_errors] = On
catch_workers_output = yes
clear_env = no
