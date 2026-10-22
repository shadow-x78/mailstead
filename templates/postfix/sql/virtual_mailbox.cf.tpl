user = mailro
password = @@DB_MAILRO_PW@@
hosts = 127.0.0.1
dbname = mailserver
query = SELECT 1 FROM mailbox WHERE username='%s' AND active='1'