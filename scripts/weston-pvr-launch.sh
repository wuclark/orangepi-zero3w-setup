#!/usr/bin/env bash
set -Eeuo pipefail

PVR_DDK_DIR="${PVR_DDK_DIR:-/opt/pvr-ddk-24.2}"
PVR_MESA_LIB="$PVR_DDK_DIR/mesa/lib"
PVR_MESA_DRI="$PVR_DDK_DIR/mesa/dri"
WESTON_LOG="${WESTON_LOG:-/home/orangepi/weston-pvr-service.log}"

export LD_LIBRARY_PATH="$PVR_MESA_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LIBGL_DRIVERS_PATH="$PVR_MESA_DRI${LIBGL_DRIVERS_PATH:+:$LIBGL_DRIVERS_PATH}"

start_wayvnc() {
    local runtime socket
    [[ -f "$HOME/.config/orangepi-zero3w-setup/wayvnc-enabled" ]] || return 0
    [[ -x /usr/bin/wayvnc ]] || return 0
    runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    (
        for _ in {1..60}; do
            socket=$(find "$runtime" -maxdepth 1 -type s -name 'wayland-*' -print -quit 2>/dev/null || true)
            if [[ -n $socket ]]; then
                export XDG_RUNTIME_DIR="$runtime"
                export WAYLAND_DISPLAY=${socket##*/}
                exec /usr/bin/wayvnc --config "$HOME/.config/wayvnc/config"
            fi
            sleep 1
        done
    ) &
}

start_wayvnc
exec /usr/bin/weston --backend=drm-backend.so --renderer=gl --log="$WESTON_LOG"
