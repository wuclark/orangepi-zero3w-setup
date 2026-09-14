#!/usr/bin/env bash
# Purpose: Provide shared constants, logging, validation, backup, copy, user,
# and board-manifest helpers.
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
MANIFEST_FILE="/etc/orangepi-zero3w-setup/manifest.json"

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

# manifest_record <step-key> <replay-command>: append a replayable receipt for
# a completed board layer (e.g. manifest_record desktop.plasma
# 'sudo make desktop-plasma'). Steps live in $MANIFEST_FILE as
# {"schema":1,"board":...,"created":..,"updated":..,"steps":{key:{"replay":..,"ts":..}}}.
# Reinstalling overwrites the same key, so the manifest always reflects
# current state. Only replay commands are stored: never pass secrets here
# (passwords, hashes, keys); replay re-prompts or regenerates them.
# Bookkeeping never breaks an install: missing python3 or an unwritable
# manifest only warns. See docs/development/data-lifecycle.md.
manifest_record() {
    local key=${1:?manifest step key required} replay=${2:?replay command required}
    command -v python3 >/dev/null 2>&1 || { warn "python3 missing; skipping manifest receipt for $key."; return 0; }
    if [[ ! -d $(dirname "$MANIFEST_FILE") ]]; then
        install -d -m 755 "$(dirname "$MANIFEST_FILE")" 2>/dev/null || { warn "Cannot stage manifest dir; skipping receipt for $key."; return 0; }
    fi
    MANIFEST_KEY=$key MANIFEST_REPLAY=$replay MANIFEST_FILE=$MANIFEST_FILE python3 - <<'EOF' || warn "Manifest receipt failed for $key."
import json, os, datetime
path = os.environ["MANIFEST_FILE"]
try:
    with open(path) as f:
        manifest = json.load(f)
    if not isinstance(manifest.get("steps"), dict):
        manifest["steps"] = {}
except (OSError, ValueError):
    manifest = {"schema": 1, "board": "unknown", "created": None, "steps": {}}
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
if manifest.get("created") is None:
    manifest["created"] = now
try:
    with open("/proc/device-tree/compatible", "rb") as f:
        board = f.read().replace(b"\0", b" ").decode().strip()
except OSError:
    board = "unknown"
manifest["board"] = board or "unknown"
manifest["updated"] = now
manifest["steps"][os.environ["MANIFEST_KEY"]] = {
    "replay": os.environ["MANIFEST_REPLAY"], "ts": now}
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(manifest, f, indent=2, sort_keys=True)
    f.write("\n")
os.replace(tmp, path)
EOF
}

# manifest_delete <step-key>: drop one receipt (uninstall paths). Best effort.
manifest_delete() {
    local key=${1:?manifest step key required}
    command -v python3 >/dev/null 2>&1 || return 0
    [[ -f $MANIFEST_FILE ]] || return 0
    MANIFEST_KEY=$key MANIFEST_FILE=$MANIFEST_FILE python3 - <<'EOF' || warn "Manifest delete failed for $key."
import json, os, sys, datetime
path = os.environ["MANIFEST_FILE"]
try:
    with open(path) as f:
        manifest = json.load(f)
except (OSError, ValueError):
    sys.exit(0)
steps = manifest.get("steps")
if isinstance(steps, dict) and steps.pop(os.environ["MANIFEST_KEY"], None) is not None:
    manifest["updated"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, path)
EOF
}

# manifest_delete_prefix <prefix>: drop every receipt under a namespace
# (e.g. desktop. when the desktop selection is reset). Best effort.
manifest_delete_prefix() {
    local prefix=${1:?manifest key prefix required}
    command -v python3 >/dev/null 2>&1 || return 0
    [[ -f $MANIFEST_FILE ]] || return 0
    MANIFEST_PREFIX=$prefix MANIFEST_FILE=$MANIFEST_FILE python3 - <<'EOF' || warn "Manifest prefix delete failed."
import json, os, sys, datetime
path = os.environ["MANIFEST_FILE"]
try:
    with open(path) as f:
        manifest = json.load(f)
except (OSError, ValueError):
    sys.exit(0)
steps = manifest.get("steps")
if isinstance(steps, dict):
    dropped = [k for k in steps if k.startswith(os.environ["MANIFEST_PREFIX"])]
    for k in dropped:
        del steps[k]
    if dropped:
        manifest["updated"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        tmp = path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(manifest, f, indent=2, sort_keys=True)
            f.write("\n")
        os.replace(tmp, path)
EOF
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
