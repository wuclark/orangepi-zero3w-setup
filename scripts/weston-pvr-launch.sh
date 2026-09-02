#!/usr/bin/env bash
set -Eeuo pipefail

PVR_DDK_DIR="${PVR_DDK_DIR:-/opt/pvr-ddk-24.2}"
PVR_MESA_LIB="$PVR_DDK_DIR/mesa/lib"
PVR_MESA_DRI="$PVR_DDK_DIR/mesa/dri"
WESTON_LOG="${WESTON_LOG:-/home/orangepi/weston-pvr-service.log}"
WAYVNC_LOG="${WAYVNC_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/orangepi-zero3w-setup-wayvnc-weston.log}"

export LD_LIBRARY_PATH="$PVR_MESA_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LIBGL_DRIVERS_PATH="$PVR_MESA_DRI${LIBGL_DRIVERS_PATH:+:$LIBGL_DRIVERS_PATH}"

start_wayvnc() {
    local runtime socket weston_pid
    [[ -f "$HOME/.config/orangepi-zero3w-setup/wayvnc-enabled" ]] || return 0
    [[ -x /usr/bin/wayvnc ]] || return 0
    runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    weston_pid=$1
    mkdir -p "$(dirname "$WAYVNC_LOG")"
    (
        sleep 1
        for _ in {1..60}; do
            kill -0 "$weston_pid" 2>/dev/null || exit 0
            socket=$(find "$runtime" -maxdepth 1 -type s -name 'wayland-*' -print -quit 2>/dev/null || true)
            if [[ -n $socket ]]; then
                export XDG_RUNTIME_DIR="$runtime"
                export WAYLAND_DISPLAY=${socket##*/}
                # Weston does not currently advertise zwlr_virtual_pointer_v1;
                # WayVNC can still provide a view-only stream in this mode.
                exec /usr/bin/wayvnc --disable-input --config "$HOME/.config/wayvnc/config" >>"$WAYVNC_LOG" 2>&1
            fi
            sleep 1
        done
        printf 'Wayland socket was not found after 60 seconds.\n' >>"$WAYVNC_LOG"
    ) &
}

/usr/bin/weston --backend=drm-backend.so --renderer=gl --log="$WESTON_LOG" &
weston_pid=$!
start_wayvnc "$weston_pid"
wait "$weston_pid"
