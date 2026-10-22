# ─────────────────────────────────────────────
# Mailstead - Dovecot IMAP Protocol
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

protocol imap {
  mail_plugins = $mail_plugins imap_quota
}
