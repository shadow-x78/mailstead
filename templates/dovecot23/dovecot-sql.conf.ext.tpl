driver = mysql
connect = host=127.0.0.1 dbname=mailserver user=mailro password=@@DB_MAILRO_PW@@
default_pass_scheme = BLF-CRYPT
password_query = SELECT username AS user, password FROM mailbox WHERE username='%u' AND active='1'
user_query = SELECT '/var/vmail/%d/%n' AS home, 5000 AS uid, 5000 AS gid, CONCAT('*:bytes=', quota) AS quota_rule FROM mailbox WHERE username='%u' AND active='1'
iterate_query = SELECT username AS user FROM mailbox WHERE active='1'