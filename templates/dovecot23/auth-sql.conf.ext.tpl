# ─────────────────────────────────────────────
# Mailstead - Dovecot SQL Authentication
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

passdb {
  driver = sql
  args = @@DOVECOT_SQL_CONF@@
}
userdb {
  driver = sql
  args = @@DOVECOT_SQL_CONF@@
  default_fields = uid=vmail gid=vmail home=/var/vmail/%d/%n
}
