# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.8.0] - 2026-10-22

### Changed

- Relicensed from GPL-3.0 to AGPL-3.0. The network-use clause keeps modifications
  public when Mailstead is offered to third parties as a service, which matches the
  project's non-commercial intent.
- Every guide moved to an upper-case name with a table of contents and stable
  anchors, so the documentation layout matches the rest of the project family.

### Added

- Arabic editions of the README and of every guide: `README_AR.md`,
  `docs/NETWORK_AR.md`, `docs/AUTOCONFIG_AR.md`, `docs/SIGNATURES_AR.md`,
  `docs/ADDING_A_DISTRO_AR.md`.
- `.gitattributes` with the linguist rules, so the configuration templates are no
  longer reported as Smarty.

### Removed

- `NAMING.md`. The repository layout now matches the project family; the naming and
  header rules stay enforced by shellcheck, shfmt and `scripts/check-comments.sh`.

## [v0.7.0] - 2026-10-22

### Changed

- docs: point the release download URLs at the GitHub Releases pages instead of a placeholder host.
- docs: add the credit banner to the issue templates and replace the placeholder `OWNER/REPO` contact links with the real repository URLs.
- chore: extend the ignore rules with the editor and merge leftovers.

## [v0.6.0] - 2026-10-22

### Changed

- docs: use the centered header with version, license, and platform badges across the documentation, and add a table of contents and anchored sections to the README.

## [v0.5.0] - 2026-10-22

### Added

- docs: open every shipped source file with the standard credit banner: the rule, the purpose line, the repository URL, and a blank line.
- ci: add `scripts/check-comments.sh` to verify the banner across the tree, and run it on every pull request.

## [v0.4.0] - 2026-10-22

### Added

- docs: add `NAMING.md` with the naming convention per name kind, the framework-required names, and the frozen contract names.
- chore: add `.editorconfig` to pin the indentation, the line endings, and the character set.

## [v0.3.0] - 2026-10-22

### Added

- feat: add the `mailstead banner` command, which prints the project logo in the terminal with 256-colour, 16-colour, and plain ASCII fallbacks.

## [v0.2.0] - 2026-10-22

### Removed

- chore: drop the unused `require_cmd`, `PKG_OPTIONAL`, and `pkg_is_optional` helpers.
- chore: strip the redundant comments that restated the surrounding code from the modules, the phases, and the templates.

### Changed

- chore: normalise the comment style in `config/versions.env`.

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
- No telemetry; all outbound connections are documented in `docs/NETWORK.md` and can be disabled with `--offline`.
