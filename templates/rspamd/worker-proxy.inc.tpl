# ─────────────────────────────────────────────
# Mailstead - Rspamd Worker Proxy Include
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

milter = yes;
timeout = 120s;
upstream "local" {
  default = yes;
  self_scan = yes;
}
bind_socket = "127.0.0.1:11332";
