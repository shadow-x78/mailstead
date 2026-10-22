# ─────────────────────────────────────────────
# Mailstead - Sieve Spam Filter Rules
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

require ["fileinto"];
if header :contains "X-Spam-Flag" "YES" {
  fileinto "Junk";
  stop;
}
