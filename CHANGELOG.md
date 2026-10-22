# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and the project uses
[Semantic Versioning](https://semver.org/).

## [0.1.0] - unreleased

### Added

- Single-command installer (`mailstead install`) with presets
  (`send-only`, `minimal`, `standard`, `full`, `custom`) and dependency resolver.
- Tier-1 support for Debian/Ubuntu and Fedora/RHEL-family through a distro
  abstraction (`lib/distro/*`). Arch and openSUSE are rejected in v1 (exit 3).
- Phases P00–P16: preflight, packages, local resolver, MariaDB, certificates,
  Postfix, Dovecot 2.3, OpenDKIM, Rspamd, PostfixAdmin, Roundcube,
  MTA-STS/TLS-RPT, autoconfig, security, DNS, backup and monitoring.
- Thunderbird autoconfig and Outlook Autodiscover (POX) generation with
  `test-autoconfig`.
- Signature system: text/HTML templates, image handling, allowlist HTML
  sanitizer (`mailstead-sig.py`), Roundcube plugin, desktop export and an
  experimental server-side footer.
- `dns-print` / `dns-check` for SPF, DKIM, DMARC, PTR/FCrDNS, MTA-STS, TLS-RPT,
  CAA and SRV records.
- Backup/restore, `doctor` (with `--redact`), `status`, `queue`, `logs`, and
  `uninstall`.
- Repository scaffolding: bats tests, shellcheck/shfmt config, CI workflow and
  documentation.

### Notes

- Dovecot 2.4 is not supported until a `templates/dovecot24/` set is provided.
- No telemetry; all outbound connections are documented in `docs/network.md` and
  can be disabled with `--offline`.