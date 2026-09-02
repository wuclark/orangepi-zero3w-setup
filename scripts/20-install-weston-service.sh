#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PVR_DDK_DIR="${PVR_DDK_DIR:-/opt/pvr-ddk-24.2}"
WESTON_USER="${WESTON_USER:-orangepi}"
WESTON_HOME=$(getent passwd "$WESTON_USER" | cut -d: -f6)
WESTON_UID=$(id -u "$WESTON_USER" 2>/dev/null || true)
PVR_MESA_LIB="$PVR_DDK_DIR/mesa/lib"
PVR_MESA_DRI="$PVR_DDK_DIR/mesa/dri"
WESTON_LOG="${WESTON_LOG:-$WESTON_HOME/weston-pvr-service.log}"
UNIT_TMP=$(mktemp)
trap 'rm -f "$UNIT_TMP"' EXIT

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'ERROR: run with sudo.' >&2; exit 1; }
[[ -n $WESTON_UID && -n $WESTON_HOME ]] || { echo "ERROR: user does not exist: $WESTON_USER" >&2; exit 1; }
[[ -x /usr/bin/weston ]] || { echo 'ERROR: /usr/bin/weston is not installed.' >&2; exit 1; }
[[ -x /usr/bin/dbus-run-session ]] || { echo 'ERROR: /usr/bin/dbus-run-session is missing.' >&2; exit 1; }
[[ -d $PVR_MESA_LIB && -d $PVR_MESA_DRI ]] || { echo "ERROR: missing PowerVR directories under $PVR_DDK_DIR" >&2; exit 1; }

install -d -m 755 /usr/local/bin /etc/systemd/system
install -m 0755 "$SCRIPT_DIR/weston-pvr-launch.sh" /usr/local/bin/weston-pvr-launch.sh
sed \
    -e "s|@WESTON_USER@|$WESTON_USER|g" \
    -e "s|@WESTON_UID@|$WESTON_UID|g" \
    -e "s|@PVR_MESA_LIB@|$PVR_MESA_LIB|g" \
    -e "s|@PVR_MESA_DRI@|$PVR_MESA_DRI|g" \
    -e "s|@PVR_DDK_DIR@|$PVR_DDK_DIR|g" \
    -e "s|@WESTON_LOG@|$WESTON_LOG|g" \
    "$SCRIPT_DIR/../systemd/weston-pvr.service" >"$UNIT_TMP"
install -m 0644 "$UNIT_TMP" /etc/systemd/system/weston-pvr.service

# Start each deployment check with a fresh, user-writable log so a stale
# successful renderer line cannot mask a failed or software-rendered restart.
install -o "$WESTON_USER" -g "$WESTON_USER" -m 0644 /dev/null "$WESTON_LOG"
/usr/bin/systemctl disable --now getty@tty1.service 2>/dev/null || true
/usr/bin/systemctl daemon-reload
/usr/bin/systemctl enable --now weston-pvr.service
sleep 3

[[ -f $WESTON_LOG ]] || { echo "ERROR: Weston log was not created: $WESTON_LOG" >&2; exit 1; }
last_renderer=$(/usr/bin/tac "$WESTON_LOG" | /usr/bin/grep -m1 'GL renderer:' || true)
if [[ $last_renderer != *PowerVR* ]]; then
    echo "ERROR: latest Weston renderer is not PowerVR: ${last_renderer:-not found}" >&2
    /usr/bin/systemctl status weston-pvr.service --no-pager -l >&2 || true
    exit 1
fi
echo "Weston PowerVR service is active: $last_renderer"
