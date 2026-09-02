#!/usr/bin/env bash
set -Eeuo pipefail

PVR_DDK_DIR="${PVR_DDK_DIR:-/opt/pvr-ddk-24.2}"
PVR_MESA_LIB="$PVR_DDK_DIR/mesa/lib"
PVR_MESA_DRI="$PVR_DDK_DIR/mesa/dri"
WESTON_LOG="${WESTON_LOG:-/home/orangepi/weston-pvr-service.log}"

export LD_LIBRARY_PATH="$PVR_MESA_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LIBGL_DRIVERS_PATH="$PVR_MESA_DRI${LIBGL_DRIVERS_PATH:+:$LIBGL_DRIVERS_PATH}"
exec /usr/bin/weston --backend=drm-backend.so --renderer=gl --log="$WESTON_LOG"
