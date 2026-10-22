# ─────────────────────────────────────────────
# Mailstead - Fail2ban Jail Filter
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

[DEFAULT]
backend = auto
bantime = 1h
findtime = 10m
maxretry = 5
@@FAIL2BAN_IGNORE@@

[postfix]
enabled = true
mode = aggressive
logpath = /var/log/mail.log
backend = auto

[postfix-sasl]
enabled = true
logpath = /var/log/mail.log
backend = auto

[dovecot]
enabled = true
logpath = /var/log/dovecot.log
backend = auto

[roundcube-auth]
enabled = true
logpath = @@ROUNDCUBE_LOGS@@/errors.log
backend = auto

[nginx-http-auth]
enabled = true
