#!/usr/bin/env bats
# tests/distro.bats - distribution detection and supported-family mapping.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export APP_ROOT="$ROOT"
    TMP="$(mktemp -d)"
    export APP_LOG_DIR="$TMP"
    export LOG_FILE="$TMP/log"
    # lib/common.sh defines run(); preserve bats' run so it can capture status.
    if declare -f run >/dev/null 2>&1; then _BATS_RUN="$(declare -f run)"; fi
    # shellcheck source=/dev/null
    source "$ROOT/lib/brand.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    if [[ -n "${_BATS_RUN:-}" ]]; then eval "$_BATS_RUN"; fi
    # shellcheck source=/dev/null
    source "$ROOT/lib/distro/detect.sh"
    DRY_RUN=1
    ASSUME_YES=1
    # Tests run on non-systemd CI hosts; bypass only the systemd gate.
    export MAILSTEAD_ALLOW_NO_SYSTEMD=1
}

teardown() { rm -rf "$TMP"; }

_write_osrel() {
    local id="$1" like="${2:-}"
    OS_RELEASE_FILE="$TMP/os-release"
    {
        printf 'ID=%s\n' "$id"
        [[ -n "$like" ]] && printf 'ID_LIKE="%s"\n' "$like"
        printf 'VERSION_ID=1\n'
        printf 'PRETTY_NAME="%s test"\n' "$id"
    } >"$OS_RELEASE_FILE"
    export OS_RELEASE_FILE
}

@test "debian maps to family debian/apt" {
    _write_osrel debian
    distro_detect
    [ "$DISTRO_FAMILY" = "debian" ]
    [ "$PKG_MGR" = "apt" ]
}

@test "ubuntu maps to family debian/apt" {
    _write_osrel ubuntu
    distro_detect
    [ "$DISTRO_FAMILY" = "debian" ]
}

@test "fedora maps to family rhel/dnf" {
    _write_osrel fedora
    distro_detect
    [ "$DISTRO_FAMILY" = "rhel" ]
    [ "$PKG_MGR" = "dnf" ]
}

@test "almalinux maps to family rhel/dnf" {
    _write_osrel almalinux "rhel centos fedora"
    distro_detect
    [ "$DISTRO_FAMILY" = "rhel" ]
}

@test "arch is rejected with exit 3" {
    _write_osrel arch
    run distro_detect
    [ "$status" -eq 3 ]
}

@test "manjaro (ID_LIKE arch) is rejected with exit 3" {
    _write_osrel manjaro "arch"
    run distro_detect
    [ "$status" -eq 3 ]
}

@test "openSUSE is rejected with exit 3" {
    _write_osrel opensuse-leap "suse"
    run distro_detect
    [ "$status" -eq 3 ]
}

@test "unknown distro is rejected unless forced" {
    _write_osrel someunknown "unknown-like"
    run distro_detect
    [ "$status" -eq 3 ]
    run distro_detect --force-unsupported
    [ "$status" -eq 0 ]
}