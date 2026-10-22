<div align="center">

# Network Connections - Mailstead

[![Version](https://img.shields.io/badge/version-0.8.5-2563eb?style=flat-square&logo=semver)](../CHANGELOG.md)
[![License](https://img.shields.io/badge/license-AGPL--3.0-dc2626?style=flat-square&logo=gnu)](../LICENSE)
![Shell](https://img.shields.io/badge/bash-5.2%2B-16a34a?style=flat-square&logo=gnubash)
![Platform](https://img.shields.io/badge/platform-Linux-9333ea?style=flat-square&logo=linux)

</div>

---

## Table of Contents

- [Outbound Connections](#outbound-connections)
- [Notes](#notes)
- [Fully Offline Install](#fully-offline-install)

---

<a id="outbound-connections"></a>
## Outbound Connections

Mailstead contains **no telemetry**. This page lists every outbound connection the
tool itself can make, what it is for, and how to disable it.

| Destination | Purpose | When | Disable |
|---|---|---|---|
| `https://api.ipify.org` | Detect the server’s public IPv4 for DNS/SPF records | `install`, unless `--ip4` is given | `--offline` (falls back to `ip route get 1.1.1.1`) |
| `github.com` (release URLs in `config/versions.env`) | Download the pinned Roundcube / PostfixAdmin tarballs (verified with SHA-256) | `install`, `upgrade-web`, when the file is not already cached | `--offline` plus a pre-placed file in `/var/lib/mailstead/cache/` |
| Let’s Encrypt ACME (`acme-v02.api.letsencrypt.org`) | Issue/renew TLS certificates via certbot or acme.sh | `install`, `cert-issue`, `cert-renew` | choose `--tls selfsigned` or `--tls existing` |
| Cloudflare API (`api.cloudflare.com`) | Only if you pass `--acme-challenge dns-cloudflare` | certificate issuance | do not enable that challenge |
| Public DNS resolvers (`1.1.1.1`, `8.8.8.8`) | `dns-check` verification queries | `dns-check` | run `dns-check` when convenient; it is read-only |

<a id="notes"></a>
## Notes

- `dig`/DNS lookups used while configuring (preflight PTR/A checks, `dns-check`,
  MX/SRV/CAA verification) are read-only and inherent to running a mail server.
- The optional local resolver (`unbound`, default on `full`) queries DNS directly
  from the server; it is not a “phone home” and can be disabled with
  `--resolver system`.
- Secrets are never sent anywhere. Generated passwords are printed to your terminal
  only.

<a id="offline-install"></a>
## Fully Offline Install

Use `--offline` with `--tls selfsigned` (or `existing`) and pre-place the
Roundcube/PostfixAdmin tarballs in the cache directory `config/versions.env`
expects.
