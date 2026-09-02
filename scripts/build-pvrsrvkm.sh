#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

OUTPUT="$PWD/pvrsrvkm.ko"
WORK_DIR="$PWD/build-pvrsrvkm"
KERNEL_REPO="https://github.com/wuclark/linux-orangepi.git"
KERNEL_BRANCH="orange-pi-6.6-sun60iw2"

usage() {
    cat <<'EOF'
Usage: build-pvrsrvkm.sh [options]

Build the Orange Pi vendor PowerVR module for the running kernel.

Options:
  --output PATH       Output module (default: ./pvrsrvkm.ko)
  --work-dir PATH     Reusable source/build directory (default: ./build-pvrsrvkm)
  --repo URL          Kernel repository override
  --branch NAME       Kernel branch override
  -h, --help          Show this help

The matching kernel headers must already be installed. The output module is not
installed automatically; review it, then use install-kernel-module.sh.
EOF
}

while (($#)); do
    case "$1" in
        --output) OUTPUT="${2:?missing path after --output}"; shift 2 ;;
        --work-dir) WORK_DIR="${2:?missing path after --work-dir}"; shift 2 ;;
        --repo) KERNEL_REPO="${2:?missing URL after --repo}"; shift 2 ;;
        --branch) KERNEL_BRANCH="${2:?missing name after --branch}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

for command in git make gcc sed find modinfo; do
    require_command "$command"
done

KERNEL_RELEASE="$(uname -r)"
KERNEL_DIR="/lib/modules/$KERNEL_RELEASE/build"
[[ -d "$KERNEL_DIR" ]] || die "Missing headers: $KERNEL_DIR"
[[ -f "$KERNEL_DIR/Makefile" ]] || die "Incomplete kernel headers in $KERNEL_DIR"

mkdir -p "$WORK_DIR"
SOURCE_DIR="$WORK_DIR/linux-orangepi"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
    [[ -z "$(find "$WORK_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] \
        || die "$WORK_DIR is not empty and lacks the expected checkout"
    log "Fetching the PowerVR module source"
    git clone --depth 1 --branch "$KERNEL_BRANCH" --filter=blob:none --sparse \
        "$KERNEL_REPO" "$SOURCE_DIR"
    git -C "$SOURCE_DIR" sparse-checkout set bsp/modules/gpu
else
    log "Using existing checkout: $SOURCE_DIR"
fi

MODULE_ROOT="$SOURCE_DIR/bsp/modules/gpu/img-bxm/linux/rogue_km"
BUILD_ROOT="$MODULE_ROOT/build/linux"
[[ -d "$BUILD_ROOT/sunxi_linux" ]] || die "PowerVR build tree not found in $MODULE_ROOT"

STUB="$KERNEL_DIR/include/linux/sunxi-sid.h"
if [[ ! -e "$STUB" ]]; then
    log "Adding the minimal sunxi-sid compatibility header required by the module"
    sudo install -d -m 755 "$(dirname "$STUB")"
    TMP_STUB="$(mktemp)"
    trap 'rm -f "$TMP_STUB"' EXIT
    cat >"$TMP_STUB" <<'EOF'
#ifndef __SUNXI_SID_H
#define __SUNXI_SID_H
#include <linux/types.h>
#include <linux/errno.h>
#define SUNXI_CHIP_SUN60IW2 (0x17330000)
#define SUNXI_CHIP_REV(p, v) ((p) + (v))
#define SUN60IW2P1_REV_A SUNXI_CHIP_REV(SUNXI_CHIP_SUN60IW2, 0x0)
static inline int sunxi_get_module_param_from_sid(void *buf, int offset, int len)
{
    return 0;
}
static inline int sunxi_get_soc_chipid(u32 *chipid)
{
    if (chipid)
        *chipid = 0;
    return 0;
}
#endif
EOF
    sudo install -m 644 "$TMP_STUB" "$STUB"
else
    log "Keeping existing header: $STUB"
fi

for makefile in \
    "$BUILD_ROOT/kbuild/Makefile.template" \
    "$BUILD_ROOT/toplevel.mk" \
    "$BUILD_ROOT/defs.mk"
do
    [[ -f "$makefile" ]] || die "Expected build file not found: $makefile"
    sed -i '/^[[:space:]]*\.SECONDARY[[:space:]]*:/d' "$makefile"
done

log "Building pvrsrvkm for $KERNEL_RELEASE"
export LICHEE_TOOLCHAIN_PATH=/usr/bin/
make -C "$BUILD_ROOT/sunxi_linux" \
    ARCH=arm64 KERNELDIR="$KERNEL_DIR" BUILD=release

BUILT_MODULE="$(find "$MODULE_ROOT" -type f -name pvrsrvkm.ko -print -quit)"
[[ -n "$BUILT_MODULE" ]] || die "Build completed but pvrsrvkm.ko was not found"

VERMAGIC="$(modinfo -F vermagic "$BUILT_MODULE")"
[[ "$VERMAGIC" == "$KERNEL_RELEASE "* ]] \
    || die "Built module vermagic '$VERMAGIC' does not match '$KERNEL_RELEASE'"

install -D -m 644 "$BUILT_MODULE" "$OUTPUT"
log "Built module: $OUTPUT"
log "vermagic: $VERMAGIC"
log "Next: sudo $SCRIPT_DIR/install-kernel-module.sh --module $OUTPUT"
