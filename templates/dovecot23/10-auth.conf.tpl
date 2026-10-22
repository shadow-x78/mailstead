# ─────────────────────────────────────────────
# Mailstead - Dovecot Authentication Settings
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

disable_plaintext_auth = yes
auth_mechanisms = plain login
auth_username_format = %Ln
!include auth-sql.conf.ext
