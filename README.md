# Mailstead

**Mailstead** builds and manages a self-hosted, production mail server on Debian,
Ubuntu, Fedora and RHEL-family systems from a single command. It wires together
Postfix, Dovecot, OpenDKIM, Rspamd, MariaDB, Nginx, Roundcube and (optionally)
PostfixAdmin, issues TLS certificates, prints/checks every DNS record, and adds
Thunderbird/Outlook autoconfig plus a signature system — tuned for high inbox
placement at Google (Gmail) and Apple (iCloud).

Mailstead is **open source only and non-commercial**. It contains **no telemetry**;
every outbound connection the tool makes is documented in [`docs/network.md`](docs/network.md)
and can be disabled with `--offline`.

- Command: `mailstead`
- Layout: runtime state lives under `/etc/mailstead`, `/var/lib/mailstead`,
  `/var/log/mailstead`, `/var/backups/mailstead`, `/opt/mailstead`.

## Supported distributions

| Tier | Distributions | Package manager |
|---|---|---|
| **Tier-1** | Debian 12/13, Ubuntu 22.04/24.04/26.04 | `apt` |
| **Tier-1** | Fedora (last two releases), AlmaLinux / Rocky / RHEL 9 & 10 | `dnf` |
| Not supported in v1 | Arch (Manjaro/EndeavourOS), openSUSE Leap/Tumbleweed (SLES) | — |
| Not supported | Alpine, Void, Gentoo, any non-systemd system | — |

Arch and openSUSE are rejected on purpose: `mailstead install` exits with code 3
and prints “unsupported in v1”. Adding a distribution is a one-file change — see
[`docs/adding-a-distro.md`](docs/adding-a-distro.md).

The distro abstraction (`pkg_install`, `svc_*`, `fw_*`, `path`, `web_user`) keeps
all `apt`/`dnf`/`www-data` specifics inside `lib/distro/*.sh`.

## Presets

| Preset | Components |
|---|---|
| `send-only` | postfix + opendkim + tls (no mailbox/db/web/spam); inbound limited to `postmaster`/`abuse` aliases |
| `minimal` | postfix + dovecot + mariadb + opendkim + rspamd + tls + fail2ban + firewall (CLI only) |
| `standard` | minimal + nginx + roundcube + autoconfig (all) + signatures (client) |
| `full` | standard + postfixadmin + mta-sts + unbound + signatures (client, optional server) |
| `custom` | from flags or an install config file |

Any flag overrides the preset; an `--config FILE` overrides the command line.
`--skip COMP[,COMP]` disables components from the chosen preset.

Key component flags:

```
--mode cli|gui  --webmail roundcube|none  --dashboard postfixadmin|none
--webserver nginx|existing|none  --db mariadb|none  --spam rspamd|none
--dkim opendkim|none  --sieve yes|no  --mta-sts yes|no  --resolver unbound|system
--autoconfig none|thunderbird|outlook|all
--signatures none|client|server  --sig-policy default|enforce  --sig-images hosted|cid
--tls letsencrypt|selfsigned|existing  --acme-client certbot|acme.sh
--acme-challenge http|standalone|dns-cloudflare  --firewall auto|ufw|firewalld|nftables|none
--fail2ban yes|no  --admin-allow-ip IP[,IP]  --staging  --dry-run  --yes
```

## Quick start

Install the tool itself (verifies nothing yet — see below), then run the installer:

```bash
sudo ./install.sh                 # copies to /opt/mailstead, links /usr/local/bin/mailstead
sudo mailstead install \
  --preset standard \
  --hostname mail.example.com \
  --domain example.com \
  --admin-email admin@example.com
```

The installer is **idempotent** and prints any generated passwords **once** at the
end. Then:

```bash
sudo mailstead dns-print example.com     # publish these records
sudo mailstead dns-check example.com     # verify SPF/DKIM/DMARC/PTR/SRV/CAA ...
sudo mailstead doctor                    # consolidated health check
```

### Verifying a release before running it

Releases are distributed as a tarball plus `sha256sum` and a GPG signature. Prefer
downloading and verifying over piping a URL into a shell:

```bash
curl -fsSLO https://example.invalid/mailstead-<version>.tar.gz
curl -fsSLO https://example.invalid/mailstead-<version>.tar.gz.sha256
sha256sum -c mailstead-<version>.tar.gz.sha256
# optionally: gpg --verify mailstead-<version>.tar.gz.asc mailstead-<version>.tar.gz
```

## CLI overview

```
mailstead install …                         # one-shot server setup
mailstead add-domain / del-domain           # per-domain DNS, DKIM, autoconfig, mta-sts
mailstead add-mailbox / del-mailbox / passwd
mailstead add-alias / del-alias / list
mailstead dkim-show / dkim-rotate
mailstead dns-print / dns-check
mailstead cert-issue / cert-renew / cert-status
mailstead autoconfig regenerate / test-autoconfig user@domain
mailstead mta-sts-enforce DOMAIN
mailstead apple-profile user@domain
mailstead sig …                             # signatures (templates/set/export/server)
mailstead components list|add|remove ; mailstead wizard
mailstead test-send / test-tls / status / queue / logs
mailstead backup / restore / upgrade-web / doctor / uninstall
```

Example session:

```
$ sudo mailstead status
=== Mailstead - حالة النظام (mail.example.com) ===
SERVICE        STATE
postfix        active
dovecot        active
opendkim       active
rspamd         active
mariadb        active
redis-server   active
nginx          active
fail2ban       active

الطابور: 0 رسالة
انتهاء الشهادة: Apr 11 12:00:00 2027 GMT
```

## Delivery quality

The tool targets Gmail/iCloud/Microsoft requirements: SPF + DKIM + DMARC alignment,
valid PTR/FCrDNS, TLS on inbound and outbound, throttled delivery to sensitive
receivers, RFC 5322-compliant messages, and a documented DMARC tightening path
(`p=none` → `quarantine` → `reject`). See `docs/` for the DNS records it prints and
the manual checks that remain (mail-tester, Postmaster Tools, desktop Outlook).

## Development

```bash
shellcheck -x mailstead install.sh lib/*.sh lib/distro/*.sh phases/*.sh
shfmt -d -i 4 -ci mailstead install.sh lib/*.sh lib/distro/*.sh phases/*.sh
bats tests/*.bats
```

CI runs the same three commands on every pull request; VM integration tests are
run manually/nightly (see [`tests/vm/`](tests/vm/)).

## Contributing & security

See [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md) and
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md). Contributions are accepted under the
Developer Certificate of Origin (`git commit -s`).

## License

GPL-3.0-or-later. See [`LICENSE`](LICENSE).