<div align="center">

# Autoconfig and Autodiscover - Mailstead

[![Version](https://img.shields.io/badge/version-0.8.5-2563eb?style=flat-square&logo=semver)](../CHANGELOG.md)
[![License](https://img.shields.io/badge/license-AGPL--3.0-dc2626?style=flat-square&logo=gnu)](../LICENSE)
![Shell](https://img.shields.io/badge/bash-5.2%2B-16a34a?style=flat-square&logo=gnubash)
![Platform](https://img.shields.io/badge/platform-Linux-9333ea?style=flat-square&logo=linux)

</div>

---

## Table of Contents

- [Thunderbird (Autoconfig)](#thunderbird-autoconfig)
- [Outlook (Autodiscover POX)](#outlook-autodiscover-pox)
- [DNS Records](#dns-records)
- [Verification](#verification)
- [Known Limitations](#known-limitations)

---

Mailstead generates client auto-configuration for a domain so users only type their
address and password.

<a id="thunderbird-autoconfig"></a>
## Thunderbird (Autoconfig)

Generate at `add-domain` (and via `mailstead autoconfig regenerate [DOMAIN|--all]`)
to `${APP_LIB}/web/autoconfig/<domain>/mail/config-v1.1.xml`, served by Nginx at:

- `https://autoconfig.<domain>/mail/config-v1.1.xml`
- `http://autoconfig.<domain>/mail/config-v1.1.xml`
- `https://<domain>/.well-known/autoconfig/mail/config-v1.1.xml` (only if the apex
  domain is hosted here)

The XML advertises IMAP `993`/SSL and SMTP `587`/STARTTLS with
`%EMAILADDRESS%` as the username. `password-cleartext` means “password sent over a
mandatory TLS channel”. The display name is XML-escaped and validated with
`xmllint` (package logical name `xmllint`).

<a id="outlook-autodiscover-pox"></a>
## Outlook (Autodiscover POX)

Outlook desktop tries, per domain:

1. `POST https://<domain>/autodiscover/autodiscover.xml`
2. `POST https://autodiscover.<domain>/autodiscover/autodiscover.xml`
3. `GET http://autodiscover.<domain>/autodiscover/autodiscover.xml` → must return
   **HTTP 302** to HTTPS (not 301)
4. DNS SRV `_autodiscover._tcp.<domain>` → `autodiscover.<domain>:443`

Mailstead covers (2), (3) and (4). Step (1) works only when the apex domain is
hosted here. The dynamic POX response is produced by
`${APP_OPT}/web/autodiscover.php` through PHP-FPM; static paths are served for
Thunderbird.

**Security:** the script never returns a non-hosted domain (404), never echoes user
input without a strict regex + XML escaping, limits the request body to 8 KB, does
not log request bodies, and Nginx applies `limit_req` (5 requests/second per IP) on
the Autodiscover path.

<a id="dns-records"></a>
## DNS Records

```
autoconfig.<d>.            A/CNAME  → mail.<d>. or the server IP
autodiscover.<d>.          A/CNAME  → mail.<d>. or the server IP
_autodiscover._tcp.<d>.    SRV      0 1 443 autodiscover.<d>.
_submission._tcp.<d>.      SRV      0 1 587 mail.<d>.
_imaps._tcp.<d>.           SRV      0 1 993 mail.<d>.
```

<a id="verification"></a>
## Verification

```bash
sudo mailstead test-autoconfig user@example.com
```

This checks the Thunderbird XML (`xmllint`), the HTTP status of both endpoints
(200 for config, **302** for Autodiscover), a POST to the Autodiscover endpoint
(verifying `<Server>` = `MAIL_HOSTNAME`, `<LoginName>` = the address, ports
993/587), that a non-hosted domain returns 404, the SRV record, and certificate
validity.

<a id="known-limitations"></a>
## Known Limitations

- **New Outlook** and the **Outlook mobile apps** do not use this mechanism fully;
  Outlook mobile goes through Microsoft cloud services and cannot be configured
  from here.
- The required manual test is **Outlook desktop on Windows (2019/2021/365)**.
- Thunderbird accounts are created from address + password only.

If a platform cannot be made to work, document the specific failure here rather
than claiming support.
