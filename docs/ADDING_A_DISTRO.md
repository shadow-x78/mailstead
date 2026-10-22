<div align="center">

# Adding a Distribution - Mailstead

[![Version](https://img.shields.io/badge/version-0.8.4-2563eb?style=flat-square&logo=semver)](../CHANGELOG.md)
[![License](https://img.shields.io/badge/license-AGPL--3.0-dc2626?style=flat-square&logo=gnu)](../LICENSE)
![Shell](https://img.shields.io/badge/bash-5.2%2B-16a34a?style=flat-square&logo=gnubash)
![Platform](https://img.shields.io/badge/platform-Linux-9333ea?style=flat-square&logo=linux)

</div>

---

## Table of Contents

- [Add the Family Module](#add-the-family-module)
- [Extend the Package Map](#extend-the-package-map)
- [Extend Detection](#extend-detection)
- [Version-Sensitive Templates](#version-sensitive-templates)
- [Documentation and Tests](#documentation-and-tests)
- [Rule of Thumb](#rule-of-thumb)

---

Mailstead isolates all distribution-specific behavior behind a small interface so a
new distribution is a single new file plus a few table entries.

<a id="add-the-family-module"></a>
## Add the Family Module

Create `lib/distro/<family>.sh` implementing the same functions as
`lib/distro/debian.sh`:

| Function | Purpose |
|---|---|
| `pkg_refresh` | refresh package metadata |
| `pkg_install LOGICAL...` | translate logical names via `pkgmap` and install |
| `pkg_installed LOGICAL...` | test whether packages are installed |
| `pkg_remove PKG...` | remove packages |
| `pkg_enable_repo NAME` | enable an extra repo (`epel`, `crb`, `rspamd`, …) |
| `svc_name LOGICAL` | map a logical service to its real unit name |
| `svc_enable_now` / `svc_reload` / `svc_restart` / `svc_active` | systemd wrappers |
| `web_user` | print the web server user (`www-data`, `nginx`, `http`, …) |
| `fw_backend` / `fw_open` / `fw_close` | firewall abstraction |
| `path LOGICAL` | distro-specific paths (nginx conf.d, php-fpm pool dir, snakeoil cert, …) |

Keep every `apt`/`dnf`/`pacman`/`zypper` and every hard-coded path **inside** this
file. Nothing else in the codebase may reference them.

<a id="extend-the-package-map"></a>
## Extend the Package Map

Add a column for the new family in `lib/distro/pkgmap.sh` (`_pkgmap_one`,
`case "${fam}:${logical}"`). Mark optional packages in `PKG_OPTIONAL` so a missing
optional package does not fail the run.

<a id="extend-detection"></a>
## Extend Detection

Update `lib/distro/detect.sh`:

- map new `ID`/`ID_LIKE` values to the family,
- keep rejecting genuinely unsupported systems with exit code 3.

<a id="version-sensitive-templates"></a>
## Version-Sensitive Templates

If the distribution ships a new major version of a component with a different
config format (for example Dovecot 2.4), add a parallel template directory
(`templates/dovecot24/`) and select it at runtime. Do not silently reuse the wrong
templates — refuse with a clear message until the templates exist.

<a id="documentation-and-tests"></a>
## Documentation and Tests

- Add the distribution to the README support table.
- Document anything marked `[تحقق]` in this file.
- Add the distribution to the VM test matrix (`tests/vm/`) and run the full
  integration checklist: full install, minimal install, add webmail afterwards,
  remove a component, idempotency, backup/restore, uninstall, and (for
  Fedora/RHEL-family) SELinux enforcing.

<a id="rule-of-thumb"></a>
## Rule of Thumb

If you find yourself writing `apt`, `dnf`, `www-data` or a `/etc/...` path outside
`lib/distro/*.sh`, stop and add it to the abstraction instead.
