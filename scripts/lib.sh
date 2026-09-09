#!/usr/bin/env bash
# Purpose: Provide shared constants, logging, validation, backup, copy, and user helpers.
# Platform: Sourced by repository setup/install scripts on host or Orange Pi as appropriate.
# Inputs: Caller-provided paths, patterns, users, environment, and command arguments.
# Dependencies: Bash built-ins and standard tools invoked by the caller; this file is not a standalone installer.
# Writes: Helper functions may write backups or copied files when invoked; sourcing alone writes nothing.
# Safety: Callers remain responsible for root checks and path scope; copy_glob only copies matched files.
# Repeat: Functions are deterministic for the same inputs; backup_file skips absent sources.
# Recovery: Recovery is owned by the calling workflow and its documented backup procedure.
# Outputs: Logging/errors and return values from the exported helper functions.
# Verification: Source through a repository script and run that script's documented checks.
# Documentation: docs/development/development.md
set -Eeuo pipefail

PROJECT_NAME="orangepi-zero3w-setup"
PVR_ROOT="/opt/pvr-ddk-24.2"
REFERENCE_KERNEL="6.6.98-vendor-sun60iw2"
REFERENCE_CODENAME="trixie"
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

check_image_drift() {
    # Compare the running kernel and OS codename against the validated
    # reference stack and abort on drift unless explicitly overridden with
    # ALLOW_UNTESTED_IMAGE=1 (or --allow-untested-image on supported
    # entrypoints). Read-only: runs uname and reads /etc/os-release, writes
    # nothing. The CLI-only base stays usable on newer images via the
    # override; kernel-module layers keep their own vermagic gates.
    local allow=${ALLOW_UNTESTED_IMAGE:-0}
    local kernel codename
    local -a mismatches=()
    kernel=$(uname -r)
    [[ $kernel == "$REFERENCE_KERNEL" ]] ||
        mismatches+=("kernel: running '$kernel', reference '$REFERENCE_KERNEL'")
    codename=$(. /etc/os-release; printf '%s' "${VERSION_CODENAME:-unknown}")
    [[ $codename == "$REFERENCE_CODENAME" ]] ||
        mismatches+=("OS codename: running '$codename', reference '$REFERENCE_CODENAME'")
    if ((${#mismatches[@]} == 0)); then
        log "Image drift check passed: kernel $kernel on $codename."
        return 0
    fi
    if [[ $allow == 1 || $allow == yes ]]; then
        local mismatch
        for mismatch in "${mismatches[@]}"; do
            warn "Untested image ($mismatch); proceeding by explicit override."
        done
        return 0
    fi
    die "Untested image: ${mismatches[*]}. This board image differs from the validated reference stack; rerun with --allow-untested-image (or ALLOW_UNTESTED_IMAGE=1) to proceed explicitly."
}
