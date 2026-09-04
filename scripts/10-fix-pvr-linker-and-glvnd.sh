#!/usr/bin/env bash
# Purpose: Configure the PowerVR linker path and GLVND EGL vendor registration.
# Platform: Orange Pi Zero 3W AArch64 board with the staged PowerVR DDK.
# Inputs: Optional PVR_DDK_DIR; defaults to /opt/pvr-ddk-24.2.
# Dependencies: Bash, root, ldconfig, eglinfo, and the installed PowerVR libraries.
# Writes: /etc/ld.so.conf.d/pvr-ddk-24.2.conf and /usr/share/glvnd/egl_vendor.d/00_pvr.json.
# Safety: Requires root; verifies directories before changing linker or GLVND configuration.
# Repeat: Idempotently maintains the linker entry and replaces the managed EGL JSON file.
# Recovery: Remove the managed files or restore the setup backup; see docs/optional/gpu/gpu.md.
# Outputs: EGL renderer diagnostics and a success/failure result.
# Verification: Successful completion must report a PowerVR OpenGL ES renderer.
# Documentation: docs/optional/gpu/gpu.md
set -Eeuo pipefail

PVR_DDK_DIR="${PVR_DDK_DIR:-/opt/pvr-ddk-24.2}"
PVR_CONF=/etc/ld.so.conf.d/pvr-ddk-24.2.conf
PVR_MESA_LIB="$PVR_DDK_DIR/mesa/lib"
PVR_MESA_DRI="$PVR_DDK_DIR/mesa/dri"
PVR_EGL_JSON=/usr/share/glvnd/egl_vendor.d/00_pvr.json

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'ERROR: run with sudo.' >&2; exit 1; }
[[ -d $PVR_MESA_LIB ]] || { echo "ERROR: missing vendor library directory: $PVR_MESA_LIB" >&2; exit 1; }
[[ -d $PVR_MESA_DRI ]] || { echo "ERROR: missing vendor DRI directory: $PVR_MESA_DRI" >&2; exit 1; }
[[ -x /sbin/ldconfig ]] || { echo 'ERROR: /sbin/ldconfig is missing.' >&2; exit 1; }
[[ -x /usr/bin/eglinfo ]] || { echo 'ERROR: /usr/bin/eglinfo is missing.' >&2; exit 1; }

install -d -m 755 /etc/ld.so.conf.d /usr/share/glvnd/egl_vendor.d
touch "$PVR_CONF"
grep -Fqx "$PVR_MESA_LIB" "$PVR_CONF" || printf '%s\n' "$PVR_MESA_LIB" >>"$PVR_CONF"
/sbin/ldconfig

cat >"$PVR_EGL_JSON" <<EOF
{
    "file_format_version" : "1.0.0",
    "ICD" : {
        "library_path" : "$PVR_MESA_LIB/libEGL.so.1"
    }
}
EOF
chmod 0644 "$PVR_EGL_JSON"

EGL_OUTPUT=$(LD_LIBRARY_PATH="$PVR_MESA_LIB" LIBGL_DRIVERS_PATH="$PVR_MESA_DRI" \
    /usr/bin/eglinfo 2>&1 || true)
printf '%s\n' "$EGL_OUTPUT"
if ! grep -qi 'OpenGL ES profile renderer:.*PowerVR' <<<"$EGL_OUTPUT"; then
    echo 'ERROR: vendor EGL/GLES verification did not report a PowerVR renderer.' >&2
    exit 1
fi
echo "PowerVR EGL/GLES linker and GLVND setup verified for $PVR_DDK_DIR."
