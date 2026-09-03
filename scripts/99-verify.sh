#!/usr/bin/env bash
# Purpose: Legacy read-only verification of the Weston PowerVR service path.
# Platform: board with the reference PowerVR DDK, Weston service, and user session.
# Inputs: optional PVR_DDK_DIR, WESTON_USER, and WESTON_LOG environment variables.
# Writes: none; reports module, linker, Vulkan, EGL, Weston, and HDMI state.
# Safety: does not install, modify services, load modules, or reboot the board.
# Repeat behavior: safe to run repeatedly; it reads current service/log state.
# Recovery: use the current board GPU workflow rather than this legacy checker.
# Verification: use only as supplemental evidence; prefer scripts/verify.sh.
set -u

PVR_DDK_DIR="${PVR_DDK_DIR:-/opt/pvr-ddk-24.2}"
WESTON_USER="${WESTON_USER:-orangepi}"
WESTON_HOME=$(getent passwd "$WESTON_USER" 2>/dev/null | cut -d: -f6)
WESTON_LOG="${WESTON_LOG:-${WESTON_HOME:-/home/orangepi}/weston-pvr-service.log}"
PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; FAIL=$((FAIL + 1)); }
root_run() {
    if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

if root_run /sbin/lsmod | /usr/bin/grep -q '^pvrsrvkm '; then pass 'pvrsrvkm is loaded'; else fail 'pvrsrvkm is not loaded'; fi
driver=$(/usr/bin/readlink -f /sys/class/drm/card1/device/driver 2>/dev/null || true)
if [[ $driver == */pvrsrvkm ]]; then pass 'card1 is bound to pvrsrvkm'; else fail "card1 driver is ${driver:-missing}"; fi

if [[ -x /usr/bin/vulkaninfo ]] && /usr/bin/vulkaninfo --summary 2>&1 | /usr/bin/grep -q 'PowerVR'; then pass 'Vulkan reports PowerVR'; else fail 'Vulkan did not report PowerVR'; fi
if /sbin/ldconfig -p 2>/dev/null | /usr/bin/grep -q 'libglapi.so.0'; then pass 'linker cache contains libglapi.so.0'; else fail 'linker cache lacks libglapi.so.0'; fi
if [[ -f /usr/share/glvnd/egl_vendor.d/00_pvr.json ]]; then pass 'PowerVR GLVND JSON exists'; else fail 'PowerVR GLVND JSON is missing'; fi

EGL_OUTPUT=$(LD_LIBRARY_PATH="$PVR_DDK_DIR/mesa/lib" LIBGL_DRIVERS_PATH="$PVR_DDK_DIR/mesa/dri" /usr/bin/eglinfo 2>&1 || true)
if grep -qi 'OpenGL ES profile renderer:.*PowerVR' <<<"$EGL_OUTPUT"; then pass 'EGL/GLES reports PowerVR'; else fail 'EGL/GLES did not report PowerVR'; fi

if /usr/bin/systemctl is-active --quiet weston-pvr.service; then pass 'weston-pvr.service is active'; else fail 'weston-pvr.service is not active'; fi
last_renderer=$(/usr/bin/tac "$WESTON_LOG" 2>/dev/null | /usr/bin/grep -m1 'GL renderer:' || true)
if [[ $last_renderer == *PowerVR* ]]; then pass 'latest Weston renderer is PowerVR'; else fail "latest Weston renderer is ${last_renderer:-missing}"; fi

hdmi_status=$(cat /sys/class/drm/card0-HDMI-A-1/status 2>/dev/null || echo unknown)
printf 'INFO  HDMI-A-1 status: %s\n' "$hdmi_status"
printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
