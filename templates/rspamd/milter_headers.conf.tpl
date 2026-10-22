# ─────────────────────────────────────────────
# Mailstead - Rspamd Milter Headers
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

use = ["x-spam-flag", "x-spam-level", "authentication-results"];
authenticated_headers = ["authentication-results"];
