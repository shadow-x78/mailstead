<div align="center">

# Adding a Distribution - Mailstead

[![Version](https://img.shields.io/badge/version-0.6.0-2563eb?style=flat-square&logo=semver)](../CHANGELOG.md)
[![License](https://img.shields.io/badge/license-GPL--3.0-dc2626?style=flat-square)](../LICENSE)
![Shell](https://img.shields.io/badge/bash-5.2%2B-16a34a?style=flat-square&logo=gnubash)
![Platform](https://img.shields.io/badge/platform-Linux-9333ea?style=flat-square&logo=linux)

</div>

---

Mailstead isolates all distribution-specific behavior behind a small interface so a
new distribution is a single new file plus a few table entries.

## 1. Add the family module

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

## 2. Extend the package map

Add a column for the new family in `lib/distro/pkgmap.sh` (`_pkgmap_one`,
`case "${fam}:${logical}"`). Mark optional packages in `PKG_OPTIONAL` so a missing
optional package does not fail the run.

## 3. Extend detection

Update `lib/distro/detect.sh`:

- map new `ID`/`ID_LIKE` values to the family,
- keep rejecting genuinely unsupported systems with exit code 3.

## 4. Version-sensitive templates

If the distribution ships a new major version of a component with a different
config format (for example Dovecot 2.4), add a parallel template directory
(`templates/dovecot24/`) and select it at runtime. Do not silently reuse the wrong
templates — refuse with a clear message until the templates exist.

## 5. Documentation and tests

- Add the distribution to the README support table.
- Document anything marked `[تحقق]` in this file.
- Add the distribution to the VM test matrix (`tests/vm/`) and run the full
  integration checklist: full install, minimal install, add webmail afterwards,
  remove a component, idempotency, backup/restore, uninstall, and (for
  Fedora/RHEL-family) SELinux enforcing.

## Rule of thumb

If you find yourself writing `apt`, `dnf`, `www-data` or a `/etc/...` path outside
`lib/distro/*.sh`, stop and add it to the abstraction instead.
