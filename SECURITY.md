<div align="center">

# Security Policy - Mailstead

[![Version](https://img.shields.io/badge/version-0.7.0-2563eb?style=flat-square&logo=semver)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-GPL--3.0-dc2626?style=flat-square)](LICENSE)
![Shell](https://img.shields.io/badge/bash-5.2%2B-16a34a?style=flat-square&logo=gnubash)
![Platform](https://img.shields.io/badge/platform-Linux-9333ea?style=flat-square&logo=linux)

</div>

---

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Report privately via
the project’s security contact (or the repository’s “Report a vulnerability”
feature). Include:

- a description and impact assessment,
- the affected version/commit,
- reproduction steps or a proof of concept,
- the output of `mailstead doctor --redact` (it masks IP addresses).

We aim to acknowledge reports promptly and to coordinate disclosure after a fix.

## Scope and hardening notes

Mailstead configures the whole mail stack, so please consider:

- **Secrets** live in `/etc/mailstead/secrets/*.pw` (mode 0600). Generated
  passwords use `[A-Za-z0-9]` only to avoid breaking config files.
- **TLS** is required for IMAP/SMTP submission; `ssl_stapling` is intentionally off.
- **SELinux** is never disabled; the installer sets the required booleans and file
  contexts instead of relaxing enforcement.
- **Firewall**: the tool never closes SSH and never enables a firewall that was
  not already running without explicit confirmation.
- **Web exposure**: the PostfixAdmin setup script is blocked after configuration;
  the Rspamd WebUI is bound to loopback and proxied behind basic auth.
- **Server footer** (`--signatures server`) is experimental and off by default; it
  is inserted before DKIM signing and never drops mail on error.

## Supported versions

Only the latest release receives security fixes.
