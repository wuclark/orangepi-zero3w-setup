#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

CONFIG_DIR=/etc/orangepi-zero3w-setup
CONFIG_FILE=$CONFIG_DIR/config
STATE_DIR=$CONFIG_DIR/state

usage() {
    cat <<'EOF'
Usage: sudo ./setup.sh base [--hostname NAME] [--timezone ZONE] [--user USER]

Creates setup state/configuration and validates the running board. This command
deliberately does not run apt update, install packages, change the GUI, or
reboot. Use the first-boot preset before booting a new SD card, then run this
command over Wi-Fi/SSH after the first login.
EOF
}

HOSTNAME_VALUE=
TIMEZONE_VALUE=
TARGET_USER=
while (($#)); do
    case "$1" in
        --hostname) HOSTNAME_VALUE=${2:?missing hostname}; shift 2 ;;
        --timezone) TIMEZONE_VALUE=${2:?missing timezone}; shift 2 ;;
        --user) TARGET_USER=${2:?missing user}; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done
require_root

ARCH=$(uname -m)
[[ $ARCH == aarch64 ]] || die "Expected arm64/aarch64; found $ARCH."
COMPAT=$(tr '\0' '\n' </proc/device-tree/compatible 2>/dev/null || true)
grep -Eqi 'a733|sun60iw2|zero3w' <<<"$COMPAT" || die \
    "This does not look like an Orange Pi Zero 3W/A733 board."

TARGET_USER=$(resolve_real_user "$TARGET_USER")
id "$TARGET_USER" >/dev/null 2>&1 || die "User does not exist: $TARGET_USER"

install -d -m 755 "$CONFIG_DIR" "$STATE_DIR"
if [[ ! -f $CONFIG_FILE ]]; then
    cat >"$CONFIG_FILE" <<EOF
# Managed by orangepi-zero3w-setup. Do not store passwords here.
TARGET_USER=$TARGET_USER
BASE_GUI=none
REMOTE_BACKEND=none
EOF
fi
if [[ -n $HOSTNAME_VALUE ]]; then
    hostnamectl set-hostname "$HOSTNAME_VALUE"
    grep -q '^HOSTNAME=' "$CONFIG_FILE" &&
        sed -i "s/^HOSTNAME=.*/HOSTNAME=$HOSTNAME_VALUE/" "$CONFIG_FILE" ||
        printf 'HOSTNAME=%s\n' "$HOSTNAME_VALUE" >>"$CONFIG_FILE"
fi
if [[ -n $TIMEZONE_VALUE ]]; then
    timedatectl set-timezone "$TIMEZONE_VALUE"
    grep -q '^TIMEZONE=' "$CONFIG_FILE" &&
        sed -i "s|^TIMEZONE=.*|TIMEZONE=$TIMEZONE_VALUE|" "$CONFIG_FILE" ||
        printf 'TIMEZONE=%s\n' "$TIMEZONE_VALUE" >>"$CONFIG_FILE"
fi
printf '%s\n' "$TARGET_USER" >"$STATE_DIR/user"
printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$STATE_DIR/base-last-run"
chmod 644 "$CONFIG_FILE" "$STATE_DIR/user" "$STATE_DIR/base-last-run"

if ip route show default 2>/dev/null | grep -q .; then
    NETWORK_STATUS="default route present"
else
    NETWORK_STATUS="no default route detected; connect Wi-Fi before package setup"
fi
log "Base validation complete for Orange Pi Zero 3W/A733."
log "CLI-only configuration recorded at $CONFIG_FILE."
log "Network: $NETWORK_STATUS"
log "No package update, GUI install, or reboot was performed."
