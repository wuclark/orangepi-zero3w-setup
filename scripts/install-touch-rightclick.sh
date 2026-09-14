#!/usr/bin/env bash
# Purpose: Install or remove the touchscreen long-press right-click daemon and service.
# Platform: systemd-based Armbian/Debian board image; requires root.
# Inputs: optional --device-name, --gesture (hold|tap-hold), --hold-ms,
#   --tap-window-ms, --move-units, --update (refresh apt
#   first), --no-start, --uninstall; apt metadata is never refreshed implicitly.
# Writes: python3-evdev package, /usr/local/sbin/orangepi-touch-rightclick,
#   /etc/systemd/system/touch-rightclick.service,
#   /etc/modules-load.d/touch-rightclick.conf (plain `uinput` line only),
#   systemd enable/start state.
# Safety: input-layer only; touches no GPU stack, boot ordering, desktop, or
#   remote configuration. The modules-load entry loads only the benign `uinput`
#   helper at boot and is unrelated to the delayed `pvrsrvkm` sequencing.
# Safety: input-layer only; touches no GPU stack, boot ordering, desktop, or
#   remote configuration. Never reboots; the caller reboots only if desired.
# Repeat behavior: idempotent; reinstalling with new flags rewrites the unit.
# Recovery: --uninstall disables the service and removes installed files;
#   plain touch input keeps working either way since the device is never grabbed.
# Verification: scripts/orangepi-touch-rightclick --self-test, then on the panel
#   hold a finger still for the context menu; check short taps and drags.
# Documentation: docs/optional/touch-rightclick.md
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

DEVICE_NAME=WS170120
GESTURE=hold
HOLD_MS=700
TAP_WINDOW_MS=400
MOVE_UNITS=12
APT_UPDATE=no
NO_START=no
ACTION=install

usage() {
    cat <<'EOF'
Usage: sudo ./setup.sh touch-rightclick [options]

Options:
  --device-name NAME   Input device substring to watch (default WS170120)
  --gesture MODE       hold (press-and-hold fires, default) or tap-hold
                       (quick tap followed by a held press fires, leaving a
                       plain long-press free for drag/select)
  --hold-ms MS         Hold deadline before right-click (default 700)
  --tap-window-ms MS   In tap-hold mode, max gap between the tap lift and
                       the held press (default 400)
  --move-units N       Movement allowance in ABS units; motion past it
                       cancels the pending click (default 12)
  --update             Run apt update before installing python3-evdev
  --no-start           Install without starting the service
  --uninstall          Disable the service and remove installed files
  -h, --help           Show this help

Installs only the long-press daemon and its service. It does not run apt
update unless --update is passed. The watched touch device is never grabbed,
so plain touch keeps working with or without the daemon.
EOF
}

while (($#)); do
    case "$1" in
        --device-name) DEVICE_NAME=${2:?missing name}; shift 2 ;;
        --gesture) GESTURE=${2:?missing mode}; shift 2 ;;
        --hold-ms) HOLD_MS=${2:?missing ms}; shift 2 ;;
        --tap-window-ms) TAP_WINDOW_MS=${2:?missing ms}; shift 2 ;;
        --move-units) MOVE_UNITS=${2:?missing units}; shift 2 ;;
        --update) APT_UPDATE=yes; shift ;;
        --no-start) NO_START=yes; shift ;;
        --uninstall) ACTION=uninstall; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

require_root

UNIT=/etc/systemd/system/touch-rightclick.service
DAEMON=/usr/local/sbin/orangepi-touch-rightclick
MODULES_CONF=/etc/modules-load.d/touch-rightclick.conf

if [[ $ACTION == uninstall ]]; then
    systemctl disable --now touch-rightclick.service 2>/dev/null || true
    rm -f "$UNIT" "$DAEMON" "$MODULES_CONF"
    systemctl daemon-reload 2>/dev/null || true
    log "Removed touchscreen long-press right-click daemon. Plain touch is unaffected."
    exit 0
fi

[[ $GESTURE == hold || $GESTURE == tap-hold ]] || die "--gesture must be hold or tap-hold."
[[ $HOLD_MS =~ ^[0-9]+$ && $HOLD_MS -gt 0 ]] || die "--hold-ms must be a positive integer."
[[ $TAP_WINDOW_MS =~ ^[0-9]+$ && $TAP_WINDOW_MS -gt 0 ]] || die "--tap-window-ms must be a positive integer."
[[ $MOVE_UNITS =~ ^[0-9]+$ ]] || die "--move-units must be a non-negative integer."
[[ -n $DEVICE_NAME ]] || die "--device-name must not be empty."

if [[ $APT_UPDATE == yes ]]; then
    apt-get update
fi
export DEBIAN_FRONTEND=noninteractive
apt-get install -y python3-evdev

"$SCRIPT_DIR/orangepi-touch-rightclick" --self-test

# The injector needs /dev/uinput, which requires the uinput module. The vendor
# image does not load it by default, so load it now and persist it across boot.
if ! modprobe uinput 2>/dev/null; then
    die "The uinput kernel module is unavailable (modprobe uinput failed). The daemon cannot inject clicks on this kernel."
fi
printf '%s\n' "uinput" >"$MODULES_CONF"
[[ -c /dev/uinput ]] || die "/dev/uinput is still missing after loading uinput; check dmesg."

install -m 755 "$SCRIPT_DIR/orangepi-touch-rightclick" "$DAEMON"
install -m 644 "$SCRIPT_DIR/../systemd/touch-rightclick.service" "$UNIT.tmp"
# Apply caller tuning to the installed unit without editing the shipped file.
sed -e "s/--device-name [^ ]*/--device-name $DEVICE_NAME/" \
    -e "s/--gesture [^ ]*/--gesture $GESTURE/" \
    -e "s/--hold-ms [^ ]*/--hold-ms $HOLD_MS/" \
    -e "s/--move-units [^ ]*/--move-units $MOVE_UNITS/" \
    "$UNIT.tmp" >"$UNIT"
rm -f "$UNIT.tmp"
systemctl daemon-reload
systemctl enable touch-rightclick.service
systemctl reset-failed touch-rightclick.service 2>/dev/null || true
if [[ $NO_START == yes ]]; then
    log "Installed touch-rightclick (not started). Start with: sudo systemctl start touch-rightclick.service"
else
    systemctl restart touch-rightclick.service
    log "Installed and started touch-rightclick (device '$DEVICE_NAME', gesture $GESTURE, hold ${HOLD_MS} ms)."
fi
log "Hold a finger still on the panel for the context menu; short taps and drags are unchanged."
