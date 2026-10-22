# Mailstead Naming Conventions

## Conventions

| Kind | Convention | Examples | Evidence |
|------|-----------|----------|----------|
| Shell function names | `snake_case` | `cmd_install`, `validate_domain`, `postconf_apply_file` | 268/324 functions (83%) |
| Private functions | `_` prefix + `snake_case` | `_tpl_replace_var`, `_c_log_write` | 56 functions (17%) |
| Global variables | `UPPER_SNAKE_CASE` | `APP_ROOT`, `LOG_FILE`, `OFFLINE` | 100% of globals |
| Local variables | `snake_case` | `cmd`, `dest`, `content` | 136/164 variables (83%) |
| File names | lowercase `.sh` | `common.sh`, `install.sh`, `debian.sh` | 35 files (majority) |
| Phase files | `P##_name.sh` | `P01_packages.sh`, `P16_report.sh` | 18 files (consistent sub-convention) |
| Template files | `kebab-case` `.tpl` | `acme-http.conf.tpl`, `config-v1.1.xml.tpl` | 45 files (majority) |
| CLI subcommands | `kebab-case` | `add-domain`, `cert-issue`, `test-autoconfig` | 29/35 commands (83%) |
| Python files | lowercase `.py` (kebab) | `mailstead-sig.py` | PEP 8 default |
| Python functions | `snake_case` | `def sanitize(text)`, `def render(template)` | 100% PEP 8 |
| Python classes | `PascalCase` | `class Sanitizer`, `class Reject` | PEP 8 |
| PHP templates | `snake_case` | `class mailstead_signature` | PHP community convention |
| Bats test files | `<component>.bats` | `common.bats`, `install.bats` | 10 files (Bats convention) |
| Directory names | lowercase | `lib`, `templates`, `phases` | 20 directories (100%) |
| Config YAML keys | `kebab-case` | `ci.yml` keys: `name`, `on`, `jobs` | YAML best practice |

## Framework-required Names (Never Change)

| Name | File | Reason |
|------|------|--------|
| `*.bats` | `tests/*.bats` | Bats runner expects this pattern |
| `*.tpl` | `templates/*` | `render_template()` references these by name |
| `P##_*.sh` | `phases/*.sh` | `INSTALL_PHASES` array dispatches by ID |
| `mailstead` | `./mailstead` | Dispatcher entry point |
| `*.conf.ext` | `templates/*/` | Dovecot includes these at runtime |
| `mailstead-sig.py` | `scripts/` | `render_template()` deploys by name |
| `autoconfig/config-v1.1.xml.tpl` | `templates/` | Thunderbird expects this path |
| `ACME-HTTP VHOST` | `templates/nginx/acme-http.conf.tpl` | Certbot expects `.well-known/acme-challenge/` |
| `sql/*.cf.tpl` | `templates/postfix/sql/` | Postfix loads by file path |

## Contract Names (Frozen)

| Name | Why frozen |
|------|-----------|
| `APP_ROOT` `APP_LIB` `APP_ETC` | Global env consumed by all modules |
| `APP_SLUG` `APP_NAME` `APP_VERSION` | Branding contract, defined in `brand.sh` |
| `DRY_RUN` `ASSUME_YES` `VERBOSE` `OFFLINE` | Global flags checked in every module |
| `TLS_CERT_FILE` `TLS_KEY_FILE` `WEB_CERT_FULLCHAIN` | TLS config values read by postfix/dovecot templates |
| `MAIL_HOSTNAME` `PRIMARY_DOMAIN` `ADMIN_EMAIL` | Core config values read by every component |
| `cmd_*` functions | `mailstead` dispatcher switches on `cmd_*` names |
| `phase_P##` functions | `install.sh` dispatches via `phase_${id}` |
| `_`-prefixed functions | Private API, not meant for external use |

## Good Examples

```bash
# GOOD: snake_case functions, _ prefix for private
cmd_install() { ... }
_tpl_replace_var() { ... }

# GOOD: UPPER_SNAKE for globals, snake_case for locals
APP_ROOT="/opt/mailstead"
local cmd dest content
```

## Check Commands

```bash
# Verify all shell files pass style checks
shellcheck -x mailstead install.sh lib/*.sh lib/distro/*.sh phases/*.sh
shfmt -d -i 4 -ci mailstead install.sh lib/*.sh lib/distro/*.sh phases/*.sh

# Verify tests pass
bats tests/*.bats
```
