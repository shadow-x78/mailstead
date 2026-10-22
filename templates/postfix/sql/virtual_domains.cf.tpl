# ─────────────────────────────────────────────
# Mailstead - Postfix Virtual Domains Map
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

user = mailro
password = @@DB_MAILRO_PW@@
hosts = 127.0.0.1
dbname = mailserver
query = SELECT domain FROM domain WHERE domain='%s' AND active='1' AND domain <> 'ALL'
