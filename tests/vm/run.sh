#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Mailstead - Virtual Machine Test Harness
# https://github.com/shadow-x78/mailstead
# ─────────────────────────────────────────────

# Run INSIDE a fresh Debian/Ubuntu or Fedora/RHEL-family VM as root:
#   VM_CONFIRM=yes ./tests/vm/run.sh
#
# It is destructive (installs/configures a mail server and, at the end, uninstalls)
# and requires network and a real domain or a placeholder like test.local.
# Do not run it on a machine you care about.

set -Eeuo pipefail
IFS=$'\n\t'

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO="$(cd -- "${HERE}/../.." && pwd -P)"

DOMAIN="${VM_DOMAIN:-test.local}"
MAIL_HOST="mail.${DOMAIN}"
ADMIN="admin@${DOMAIN}"
PASS=0
FAIL=0

if [[ "$(id -u)" -ne 0 ]]; then
    echo "run as root inside a throwaway VM" >&2
    exit 1
fi
if [[ "${VM_CONFIRM:-no}" != "yes" ]]; then
    echo "refusing to run: set VM_CONFIRM=yes to acknowledge this is destructive" >&2
    exit 1
fi

check() {
    local label="$1"
    shift
    if "$@"; then
        printf '  ✔ %s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf '  ✘ %s\n' "$label"
        FAIL=$((FAIL + 1))
    fi
}

step() { printf '\n=== %s ===\n' "$1"; }

step "install tool"
"${REPO}/install.sh"

step "dry-run changes nothing"
mailstead install --preset standard --hostname "$MAIL_HOST" --domain "$DOMAIN" \
    --admin-email "$ADMIN" --cert selfsigned --dry-run --yes
check "no config yet" test ! -f /etc/mailstead/mailstead.conf

step "full install (self-signed)"
mailstead install --preset standard --hostname "$MAIL_HOST" --domain "$DOMAIN" \
    --admin-email "$ADMIN" --cert selfsigned --yes

step "idempotency (re-run)"
mailstead install --preset standard --hostname "$MAIL_HOST" --domain "$DOMAIN" \
    --admin-email "$ADMIN" --cert selfsigned --yes

step "services"
for s in postfix dovecot opendkim rspamd nginx; do
    check "$s active" systemctl is-active --quiet "$s"
done

step "domains and mailboxes"
mailstead add-mailbox "user@${DOMAIN}" --password "TestPass1234" --name "Test User"
check "mailbox authenticates" doveadm auth test "user@${DOMAIN}" "TestPass1234"
check "list shows mailbox" bash -c "mailstead list mailboxes '${DOMAIN}' | grep -q user@"

step "internal delivery via swaks"
check "swaks submit" swaks --to "user@${DOMAIN}" --from "$ADMIN" \
    --server 127.0.0.1 --port 25 --header "Subject: internal test"

step "GTUBE goes to Junk"
printf 'Subject: gtube\n\nXJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X\n' >/tmp/gtube.eml
check "gtube submit" swaks --to "user@${DOMAIN}" --from "$ADMIN" \
    --server 127.0.0.1 --port 25 --data /tmp/gtube.eml

step "backup and restore"
mailstead backup --dest /tmp/vmbackup
LATEST="$(find /tmp/vmbackup -name 'mailstead-*.tar.gz' | sort | tail -n1)"
check "backup exists" test -n "$LATEST"
check "restore runs" mailstead restore "$LATEST" --yes

step "uninstall"
mailstead uninstall --purge --yes

step "summary"
printf 'PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
