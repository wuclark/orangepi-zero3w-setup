#!/usr/bin/env bash
# Purpose: Stage the matching Orange Pi kernel source for PowerVR module builds.
# Platform: host or preloaded board checkout with Git and network/source access.
# Inputs: SOURCE_ROOT, KERNEL_REPO, KERNEL_BRANCH environment overrides.
# Writes: a sparse Git checkout at build-pvrsrvkm/linux-orangepi by default.
# Safety: uses the board-specific branch and refuses to overwrite a non-Git path.
# Repeat behavior: reuses an existing checkout and fetches the configured revision.
# Recovery: remove only a verified failed private checkout, then rerun kernel-source.
# Verification: inspect the branch/revision and run the module ABI check on the board.
set -Eeuo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SOURCE_ROOT=${SOURCE_ROOT:-$REPO_ROOT/build-pvrsrvkm}
SOURCE_DIR="$SOURCE_ROOT/linux-orangepi"
KERNEL_REPO=${KERNEL_REPO:-https://github.com/wuclark/linux-orangepi.git}
KERNEL_BRANCH=${KERNEL_BRANCH:-orange-pi-6.6-sun60iw2}

command -v git >/dev/null 2>&1 || { echo 'ERROR: git is required' >&2; exit 1; }
mkdir -p "$SOURCE_ROOT"

if [[ -d "$SOURCE_DIR/.git" ]]; then
    echo "Using existing PowerVR module source: $SOURCE_DIR"
elif [[ -e "$SOURCE_DIR" ]]; then
    echo "ERROR: source destination exists but is not a Git checkout: $SOURCE_DIR" >&2
    exit 1
else
    echo "Fetching the PowerVR module source"
    git clone --depth 1 --branch "$KERNEL_BRANCH" --filter=blob:none --sparse \
        "$KERNEL_REPO" "$SOURCE_DIR"
    git -C "$SOURCE_DIR" sparse-checkout set bsp/modules/gpu
fi

[[ -d "$SOURCE_DIR/bsp/modules/gpu/img-bxm/linux/rogue_km/build/linux/sunxi_linux" ]] \
    || { echo "ERROR: PowerVR build tree not found in $SOURCE_DIR" >&2; exit 1; }
echo "Prepared PowerVR module source at $SOURCE_DIR"
