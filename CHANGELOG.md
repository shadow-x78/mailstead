# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.1.0] - 2026-10-22

### Added

- feat: add the single-command installer (`mailstead install`) with the `send-only`, `minimal`, `standard`, `full`, and `custom` presets and a dependency resolver.
- feat: add Tier-1 support for Debian/Ubuntu and Fedora/RHEL-family through a distro abstraction (`lib/distro/*`). Arch and openSUSE are rejected in v1 with exit code 3.
- feat: add the installer phases P00-P16: preflight, packages, local resolver, MariaDB, certificates, Postfix, Dovecot 2.3, OpenDKIM, Rspamd, PostfixAdmin, Roundcube, MTA-STS/TLS-RPT, autoconfig, security, DNS, backup, and monitoring.
- feat: add the web stack with Nginx, Roundcube webmail, and the PostfixAdmin dashboard.
- feat: add spam filtering with Rspamd and DKIM signing with OpenDKIM.
- feat: add security hardening, `dns-print` and `dns-check`, backup and restore, and the `doctor`, `status`, `queue`, and `logs` reports.
- feat: add Thunderbird autoconfiguration, Outlook Autodiscover (POX), and MTA-STS endpoints.
- feat: add the email signature engine with text and HTML templates, image handling, an allowlist HTML sanitizer (`mailstead-sig.py`), a Roundcube plugin, desktop export, and an experimental server-side footer.
- test: add the bats suites and the virtual machine harness.
- docs: add the README, the guides, and the governance documents.
- ci: add the GitHub Actions workflow and the issue templates.

### Notes

- Dovecot 2.4 is not supported until a `templates/dovecot24/` set is provided.
- No telemetry; all outbound connections are documented in `docs/network.md` and can be disabled with `--offline`.
