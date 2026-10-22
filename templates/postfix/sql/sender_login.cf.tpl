user = mailro
password = @@DB_MAILRO_PW@@
hosts = 127.0.0.1
dbname = mailserver
query = SELECT username FROM mailbox WHERE username='%s' AND active='1' UNION SELECT goto FROM alias WHERE address='%s' AND active='1'