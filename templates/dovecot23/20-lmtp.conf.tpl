# ─────────────────────────────────────────────
# Mailstead - Dovecot LMTP Delivery
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

protocol lmtp {
  mail_plugins = $mail_plugins sieve
}
