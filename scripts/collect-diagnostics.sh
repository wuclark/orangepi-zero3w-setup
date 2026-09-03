#!/usr/bin/env bash
# Purpose: Capture broad board diagnostics for troubleshooting and support evidence.
# Platform: running Orange Pi board; commands may need sudo for debugfs/service data.
# Inputs: optional output filename; default is a timestamped file in the user home.
# Writes: one diagnostic text file containing system, services, DRM, Vulkan, and logs.
# Safety: output can contain host/session details; sanitize before sharing or committing.
# Repeat behavior: creates a new timestamped file unless an explicit path is supplied.
# Recovery: collection tolerates unavailable optional commands and continues.
# Verification: inspect the file for kernel, module vermagic, BVNC, DRM, and GPU evidence.
set -Eeuo pipefail
OUTPUT=${1:-"$HOME/zero3w-pvr-diagnostics-$(date -u +%Y%m%dT%H%M%SZ).txt"}

{
    echo '===== SYSTEM ====='
    uname -a
    cat /etc/os-release
    echo '===== SERVICES ====='
    systemctl status pvr-late-load.service lightdm.service x11vnc.service --no-pager -l || true
    echo '===== MODULE ====='
    lsmod | grep -E 'pvrsrvkm|pvr' || true
    modinfo /opt/pvrsrvkm.ko 2>/dev/null || true
    echo '===== DRM ====='
    ls -la /dev/dri || true
    sudo sh -c 'for f in /sys/kernel/debug/dri/*/name; do echo "--- $f"; cat "$f"; done' || true
    echo '===== VULKAN ====='
    env -u DISPLAY VK_ICD_FILENAMES=/etc/vulkan/icd.d/img_icd.json vulkaninfo --summary || true
    echo '===== X11 ====='
    DISPLAY=:0 xdpyinfo | grep -E 'dimensions:|DRI2|DRI3|Present' || true
    echo '===== EGL ====='
    LD_LIBRARY_PATH=/opt/pvr-ddk-24.2/mesa/lib:/opt/pvr-ddk-24.2/lib LIBGL_DRIVERS_PATH=/opt/pvr-ddk-24.2/mesa/dri eglinfo -B || true
    echo '===== XORG LOG ====='
    sudo grep -Ei 'pvr|sunxi|renderD|card[01]|glamor|EGL|GBM|DRI|failed|error' /var/log/Xorg.0.log | tail -n 250 || true
    echo '===== DMESG ====='
    sudo dmesg | grep -Ei 'pvrsrvkm|PVR_K|RGX|drm|fault|error' | tail -n 250 || true
} 2>&1 | tee "$OUTPUT"

echo "Saved diagnostics to $OUTPUT"
