#!/usr/bin/env bash

APP_NAME="Mailstead"
APP_SLUG="mailstead"
APP_CMD="mailstead"
APP_VERSION="0.4.0"

APP_ETC="/etc/${APP_SLUG}"
APP_LIB="/var/lib/${APP_SLUG}"
APP_LOG="/var/log/${APP_SLUG}"
APP_BACKUP="/var/backups/${APP_SLUG}"
APP_OPT="/opt/${APP_SLUG}"
APP_LIBEXEC="/usr/libexec/${APP_SLUG}"
APP_USER_AGENT="${APP_SLUG}/${APP_VERSION}"

APP_ROOT="${APP_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"
APP_EXPORT="$APP_ROOT"

APP_MANAGED_MARK="# Managed by ${APP_NAME} - do not edit"

EX_OK=0
EX_ERR=1
EX_USAGE=2
EX_PREFLIGHT=3
EX_VERIFY=4
EX_UNSUPPORTED=3
