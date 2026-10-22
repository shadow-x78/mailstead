#!/usr/bin/env bash
# install.sh - install the Mailstead tool itself into ${APP_OPT} and link it.
# This does NOT configure the mail server; run `mailstead install` afterwards.
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/brand.sh
. "${SRC}/lib/brand.sh"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "install.sh must be run as root." >&2
    exit 1
fi

echo "installing ${APP_NAME} into ${APP_OPT}..."
install -d -m 0755 "$APP_OPT"
# Copy the tree but never overwrite runtime state directories.
for item in mailstead lib phases templates config scripts docs README.md LICENSE \
    CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md CHANGELOG.md; do
    [[ -e "${SRC}/${item}" ]] || continue
    cp -a -- "${SRC}/${item}" "${APP_OPT}/"
done

chmod 0755 "${APP_OPT}/mailstead"
install -d -m 0755 /usr/local/bin
ln -sfn "${APP_OPT}/mailstead" "/usr/local/bin/${APP_CMD}"

echo "done. the command is available: ${APP_CMD} --help"
echo "next: ${APP_CMD} install --domain example.com --admin-email admin@example.com"
