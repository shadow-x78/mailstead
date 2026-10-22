<div align="center">

# Contributing to Mailstead

[![Version](https://img.shields.io/badge/version-0.8.3-2563eb?style=for-the-badge&logo=semver)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-AGPL--3.0-dc2626?style=for-the-badge&logo=gnu)](LICENSE)
![Shell](https://img.shields.io/badge/bash-5.2%2B-16a34a?style=for-the-badge&logo=gnubash)
![Platform](https://img.shields.io/badge/platform-Linux-9333ea?style=for-the-badge&logo=linux)

</div>

---

Thanks for your interest. Mailstead is a Bash tool; contributions should keep it
portable, idempotent and shellcheck/shfmt clean.

## Development setup

Required tools: `bash` >= 5, `shellcheck`, `shfmt`, `bats` (bats-core) and
`python3` (for the signature helper). Run the same checks CI runs:

```bash
shellcheck -x mailstead install.sh lib/*.sh lib/distro/*.sh phases/*.sh
shfmt -d -i 4 -ci mailstead install.sh lib/*.sh lib/distro/*.sh phases/*.sh
bash scripts/check-comments.sh
bats tests/*.bats
```

## Coding rules

- Every file starts with the standard credit banner, then one blank line. The
  banner names the file's purpose; do not repeat the title in a second comment.
- Every script starts with `set -Eeuo pipefail`, `IFS=$'\n\t'`, `umask 027`.
- Every function is idempotent and honours `--dry-run`.
- **Never** rewrite `/etc/postfix/main.cf` or `master.cf` wholesale — use
  `postconf -e` / `postconf -M` / `postconf -P`.
- **Never** use `envsubst` or `sed` to fill templates. Use `render_template` with
  `@@NAME@@` placeholders and the `TPL_VARS` list.
- Do not use `${var//pat/rep}` with an `&` in the replacement: Bash 5.3 treats `&`
  as the matched text. Use helper functions (`_tpl_replace_var`, `xml_escape`).
- Keep distribution-specific code (`apt`, `dnf`, `www-data`, paths) inside
  `lib/distro/*.sh`. Add a new distro with a single family module (see
  `docs/ADDING_A_DISTRO.md`).
- User-facing messages are in Arabic; code and comments are in English.
- No `TODO`, no placeholders — every file ships complete.

## Adding a distribution

1. Add a `lib/distro/<family>.sh` implementing the interface in `lib/distro/debian.sh`
   (`pkg_refresh`, `pkg_install`, `pkg_installed`, `pkg_remove`, `pkg_enable_repo`,
   `svc_name`, `svc_*`, `web_user`, `fw_backend`, `fw_open`, `fw_close`, `path`).
2. Add its columns to `lib/distro/pkgmap.sh`.
3. Extend `distro_detect` in `lib/distro/detect.sh`.
4. Update `docs/ADDING_A_DISTRO.md`, the README table, and the VM matrix.

## Commits

Sign off your commits (DCO):

```bash
git commit -s -m "postfix: ..."
```

By contributing you agree your work is licensed under AGPL-3.0-or-later.

## Reporting bugs

Include the output of `mailstead doctor --redact` (it strips secrets and IPs) and
the relevant lines from `/var/log/mailstead/mailstead.log`.
