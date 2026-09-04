#!/usr/bin/env bash
# Purpose: Install PowerVR userspace libraries, DRI/ICD files, and matching firmware from a staged root.
# Platform: Orange Pi Zero 3W AArch64 reference PowerVR DDK stack.
# Inputs: Required --vendor-root and optional --firmware-dir paths from a privately staged vendor archive.
# Dependencies: Bash, root, scripts/lib.sh, and the expected proprietary vendor file layout.
# Writes: /opt/pvr-ddk-24.2 managed libraries/DRI/ICD files and /usr/lib/firmware PowerVR firmware.
# Safety: Reads only the supplied staged root; never extracts archives and validates required files before install.
# Repeat: Replaces managed files and symlinks while preserving unrelated system files.
# Recovery: Restore the userspace backup from the setup workflow; do not delete shared system firmware blindly.
# Outputs: Installed PowerVR userspace/firmware paths and failure diagnostics for missing vendor files.
# Verification: Run the GPU ABI, EGL/GLES, Vulkan, and board validation checks.
# Documentation: docs/optional/gpu/gpu.md
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

VENDOR_ROOT=""
FIRMWARE_DIR=""

while (($#)); do
    case "$1" in
        --vendor-root) VENDOR_ROOT=${2:?}; shift 2 ;;
        --firmware-dir) FIRMWARE_DIR=${2:?}; shift 2 ;;
        -h|--help)
            echo "Usage: sudo $0 --vendor-root ROOT [--firmware-dir DIR]"
            exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

[[ -d $VENDOR_ROOT ]] || die "Vendor root not found: $VENDOR_ROOT"
FIRMWARE_DIR=${FIRMWARE_DIR:-$VENDOR_ROOT/usr/lib/firmware}

install -d -m 755 "$PVR_ROOT/lib" "$PVR_ROOT/mesa/lib" "$PVR_ROOT/mesa/dri" "$PVR_ROOT/vulkan"

for pattern in \
    'libVK_IMG.so*' \
    'libsrv_um.so*' \
    'libusc.so*' \
    'libufwriter.so*' \
    'libglslcompiler.so*' \
    'libpvr_dri_support.so*' \
    'libGLESv1_CM_PVR_MESA.so*' \
    'libGLESv2_PVR_MESA.so*'
do
    copy_glob "$VENDOR_ROOT/usr/lib" "$pattern" "$PVR_ROOT/lib" yes
done

for pattern in \
    'libPVROCL.so*' \
    'libPVRScopeServices.so*' \
    'libOpenCL.so*' \
    'libsutu_display.so*'
do
    copy_glob "$VENDOR_ROOT/usr/lib" "$pattern" "$PVR_ROOT/lib" no
done

for pattern in \
    'libEGL.so*' \
    'libgbm.so*' \
    'libglapi.so*' \
    'libGLESv1_CM.so*' \
    'libGLESv2.so*'
do
    copy_glob "$VENDOR_ROOT/usr/local/lib" "$pattern" "$PVR_ROOT/mesa/lib" yes
done

copy_glob "$VENDOR_ROOT/usr/local/lib" 'libpvr_mesa_wsi.so*' "$PVR_ROOT/lib" yes

DRI_SOURCE="$VENDOR_ROOT/usr/local/lib/dri/pvr_dri.so"
[[ -f $DRI_SOURCE ]] || DRI_SOURCE="$VENDOR_ROOT/usr/lib/aarch64-linux-gnu/dri/pvr_dri.so"
[[ -f $DRI_SOURCE ]] || die "Missing pvr_dri.so in vendor root."
install -m 755 "$DRI_SOURCE" "$PVR_ROOT/mesa/dri/pvr_dri.so"

for alias in sunxi-drm_dri.so sunxi_drm_dri.so libdril_dri.so swrast_dri.so kms_swrast_dri.so; do
    ln -sfn pvr_dri.so "$PVR_ROOT/mesa/dri/$alias"
done

for firmware in "rgx.fw.$REFERENCE_BVNC" "rgx.sh.$REFERENCE_BVNC"; do
    [[ -f $FIRMWARE_DIR/$firmware ]] || die "Missing firmware: $FIRMWARE_DIR/$firmware"
    install -m 644 "$FIRMWARE_DIR/$firmware" "/usr/lib/firmware/$firmware"
done

install -m 644 "$REPO_ROOT/config/img_icd.json" "$PVR_ROOT/vulkan/img_icd.json"
install -d -m 755 /etc/vulkan/icd.d
install -m 644 "$REPO_ROOT/config/img_icd.json" /etc/vulkan/icd.d/img_icd.json

printf '%s\n' "$PVR_ROOT/lib" > /etc/ld.so.conf.d/pvr-ddk-24.2.conf
ldconfig

for library in "$PVR_ROOT/lib/libVK_IMG.so" "$PVR_ROOT/lib/libpvr_mesa_wsi.so" "$PVR_ROOT/lib/libGLESv2_PVR_MESA.so"; do
    [[ -e $library ]] || die "Installed library missing: $library"
    if LD_LIBRARY_PATH="$PVR_ROOT/mesa/lib:$PVR_ROOT/lib" ldd "$library" | grep -q 'not found'; then
        LD_LIBRARY_PATH="$PVR_ROOT/mesa/lib:$PVR_ROOT/lib" ldd "$library" >&2
        die "Unresolved dependencies in $library"
    fi
done

log "Installed isolated PowerVR userspace under $PVR_ROOT."
