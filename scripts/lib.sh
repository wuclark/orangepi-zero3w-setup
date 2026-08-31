#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_NAME="orangepi-zero3w-setup"
PVR_ROOT="/opt/pvr-ddk-24.2"
REFERENCE_KERNEL="6.6.98-vendor-sun60iw2"
REFERENCE_BVNC="36.56.104.183"

log() { printf '[%s] %s\n' "$PROJECT_NAME" "$*"; }
warn() { printf '[%s] WARNING: %s\n' "$PROJECT_NAME" "$*" >&2; }
die() { printf '[%s] ERROR: %s\n' "$PROJECT_NAME" "$*" >&2; exit 1; }

require_root() {
    [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run this command with sudo."
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

backup_file() {
    local source=$1 backup_root=$2 relative
    [[ -e $source || -L $source ]] || return 0
    relative=${source#/}
    install -d -m 755 "$backup_root/$(dirname "$relative")"
    cp -a "$source" "$backup_root/$relative"
}

copy_glob() {
    local source_dir=$1 pattern=$2 destination=$3 required=${4:-yes}
    local -a matches=()
    shopt -s nullglob
    matches=("$source_dir"/$pattern)
    shopt -u nullglob
    if ((${#matches[@]} == 0)); then
        [[ $required == yes ]] && die "Missing vendor files: $source_dir/$pattern"
        return 0
    fi
    cp -a "${matches[@]}" "$destination/"
}

resolve_real_user() {
    local requested=${1:-}
    if [[ -n $requested ]]; then
        printf '%s\n' "$requested"
    elif [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]]; then
        printf '%s\n' "$SUDO_USER"
    else
        printf 'orangepi\n'
    fi
}
