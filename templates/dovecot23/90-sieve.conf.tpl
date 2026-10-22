# ─────────────────────────────────────────────
# Mailstead - Dovecot Sieve Support
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

plugin {
  sieve = file:~/sieve;active=~/.dovecot.sieve
  sieve_before = /etc/dovecot/sieve/before.d
  sieve_dir = ~/sieve
}
