# ─────────────────────────────────────────────
# Mailstead - Postfix Catch-all Alias Map
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

user = mailro
password = @@DB_MAILRO_PW@@
hosts = 127.0.0.1
dbname = mailserver
query = SELECT goto FROM alias WHERE address=CONCAT('@','%d') AND active='1'
