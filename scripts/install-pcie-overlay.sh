#!/usr/bin/env bash
# Purpose: Install, remove, or report the experimental PCIe HAT overlay state.
# Platform: Orange Pi Zero 3W (A733) with Armbian-style /boot/armbianEnv.txt;
# install/uninstall require root on the board; --status is read-only.
# Inputs: optional --update (refresh apt metadata), --status (read-only report),
# --uninstall (remove the overlay reference); default action installs.
# Dependencies: Bash, root for install/uninstall, apt-get, device-tree-compiler,
# pciutils, usbutils, and overlays/sun60iw2-pcie-gen2.dts in this repository.
# Writes: install compiles the overlay to /boot/overlay-user/sun60iw2-pcie-gen2.dtbo,
# backs up /boot/armbianEnv.txt with a timestamp, and merges the overlay name into
# user_overlays while preserving existing entries. Uninstall edits only the
# user_overlays line (the .dtbo file is left inert on disk).
# Safety: apt metadata refresh occurs only with --update; no reboot is performed
# (PCIe needs a manual cold boot: power off, wait ~10 s, then boot with the HAT
# connected). Never hot-plug PCIe in this setup.
# Repeat: installation is idempotent; reruns recompile, reinstall, and keep a single
# user_overlays entry with a fresh backup each time.
# Recovery: restore the printed timestamped armbianEnv.txt backup, or rerun with
# --uninstall, then cold boot. See docs/optional/pcie.md for rollback steps.
# Outputs: progress log, backup path, final boot configuration, and the exact cold-boot
# and verification commands.
# Verification: after a cold boot run `make board-pcie-status` and expect
# max-link-speed <0x02>, PD22/PD23 GPIO properties, "pcie link up success" /
# "PCIe speed of Gen2" in dmesg, and downstream devices in lspci.
# Documentation: docs/optional/pcie.md
set -Eeuo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OVERLAY_NAME="sun60iw2-pcie-gen2"
DTS_SOURCE="$REPO_ROOT/overlays/$OVERLAY_NAME.dts"
BOOT_ENV="/boot/armbianEnv.txt"
OVERLAY_DIR="/boot/overlay-user"
INSTALLED_DTBO="$OVERLAY_DIR/$OVERLAY_NAME.dtbo"
EXPECTED_FDT="allwinner/sun60i-a733-orangepi-zero3w.dtb"
PCIE_NODE="/proc/device-tree/soc@3000000/pcie@6000000"

ACTION=install
UPDATE=no

usage() {
    cat <<'EOF'
Usage: sudo ./setup.sh pcie [--install|--status|--uninstall] [--update]

Install the experimental PCIe HAT overlay (default), report its state, or
remove its boot reference.

  --install    compile and stage the overlay, merge it into user_overlays
  --status     read-only: show boot config, overlay file, live DT, dmesg, lspci
  --uninstall  remove the overlay name from user_overlays (keeps the .dtbo file)
  --update     refresh apt metadata before installing packages (default uses
               the existing apt cache)
  -h, --help   show this help

The installer never reboots. After install or uninstall, cold boot:
power off, remove power for ~10 s, then boot with the HAT already connected.
EOF
}

while (($#)); do
    case "$1" in
        --install) ACTION=install; shift ;;
        --status) ACTION=status; shift ;;
        --uninstall) ACTION=uninstall; shift ;;
        --update) UPDATE=yes; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ $ACTION == status ]]; then
    exec "$REPO_ROOT/scripts/board-pcie-status.sh"
fi

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Run install/uninstall with sudo.' >&2; exit 1; }

[[ -f $DTS_SOURCE ]] || { echo "Missing overlay source: $DTS_SOURCE" >&2; exit 1; }
[[ -f $BOOT_ENV ]] || {
    echo "Missing $BOOT_ENV; this installer expects the Armbian-style boot layout." >&2
    exit 1
}

if [[ $ACTION == uninstall ]]; then
    STAMP="$(date +%Y%m%d-%H%M%S)"
    BACKUP="$BOOT_ENV.backup-before-$OVERLAY_NAME-remove-$STAMP"
    cp -a "$BOOT_ENV" "$BACKUP"
    echo "Backup created: $BACKUP"
    # Remove only our overlay name from the space-separated list, preserving others.
    CURRENT="$(awk -F= '/^user_overlays=/{print $2}' "$BOOT_ENV" | tail -n1 || true)"
    NEW=""
    # shellcheck disable=SC2086: word splitting over the overlay list is intended.
    for item in $CURRENT; do
        [[ $item == "$OVERLAY_NAME" ]] || NEW+="$item "
    done
    NEW="$(echo "$NEW" | xargs || true)"
    sed -i '/^user_overlays=/d' "$BOOT_ENV"
    [[ -n $NEW ]] && printf 'user_overlays=%s\n' "$NEW" >>"$BOOT_ENV"
    echo "Removed '$OVERLAY_NAME' from user_overlays (remaining: '${NEW:-none}')."
    echo "The file $INSTALLED_DTBO is left inert on disk; delete it manually if unwanted."
    echo 'Cold boot to apply: sudo poweroff, remove power ~10 s, then boot.'
    exit 0
fi

# --- install path ---
echo "Orange Pi Zero 3W PCIe HAT overlay installer ($OVERLAY_NAME)"
echo "Architecture: $(uname -m)"
echo "Kernel:       $(uname -r)"
[[ $(uname -m) == aarch64 ]] || echo 'WARN: expected aarch64.' >&2
if [[ -d $PCIE_NODE ]]; then
    echo 'PCIe node:    found in live device tree'
else
    echo "WARN: live PCIe node $PCIE_NODE not found; check base DT/kernel." >&2
fi
if grep -q "^fdtfile=${EXPECTED_FDT}$" "$BOOT_ENV"; then
    echo "FDT:          $EXPECTED_FDT"
else
    echo "WARN: expected fdtfile=$EXPECTED_FDT; current:" >&2
    grep '^fdtfile=' "$BOOT_ENV" || true
fi

if ! command -v dtc >/dev/null 2>&1; then
    echo 'device-tree-compiler will be installed from packages below.'
fi

echo '--- packages (device-tree-compiler, pciutils, usbutils) ---'
if [[ $UPDATE == yes ]]; then
    apt-get update
else
    echo 'Using the existing apt cache; no apt update was run (pass --update to refresh).'
fi
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends device-tree-compiler pciutils usbutils

echo '--- compiling overlay ---'
TMP_DTBO=$(mktemp -t "$OVERLAY_NAME".XXXXXXXX.dtbo)
trap 'rm -f -- "$TMP_DTBO"' EXIT
dtc -@ -I dts -O dtb -o "$TMP_DTBO" "$DTS_SOURCE"
[[ -s $TMP_DTBO ]] || { echo 'Overlay compilation produced no output.' >&2; exit 1; }

echo '--- validating compiled overlay ---'
DECOMPILED=$(dtc -I dtb -O dts "$TMP_DTBO" 2>/dev/null || true)
echo "$DECOMPILED" | grep -q 'max-link-speed = <0x02>' \
    || { echo 'Compiled overlay lacks max-link-speed = <2>.' >&2; exit 1; }
echo "$DECOMPILED" | grep -q 'reset-gpios' \
    || { echo 'Compiled overlay lacks reset-gpios.' >&2; exit 1; }
echo "$DECOMPILED" | grep -q 'power-gpios' \
    || { echo 'Compiled overlay lacks power-gpios.' >&2; exit 1; }
echo "$DECOMPILED" | grep -q '__fixups__' \
    || { echo 'Compiled overlay lacks __fixups__; &pio may not resolve.' >&2; exit 1; }
echo "$DECOMPILED" | grep -q 'pio =' \
    || { echo 'Compiled overlay lacks the pio fixup.' >&2; exit 1; }
echo 'Compiled overlay validated (Gen2 target, reset/power GPIOs, pio fixup).'

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BOOT_ENV.backup-before-$OVERLAY_NAME-$STAMP"
cp -a "$BOOT_ENV" "$BACKUP"
echo "Backup created: $BACKUP"

install -d -m 755 "$OVERLAY_DIR"
cp -f -- "$TMP_DTBO" "$INSTALLED_DTBO"
chmod 0644 "$INSTALLED_DTBO"
echo "Installed: $INSTALLED_DTBO"

CURRENT="$(awk -F= '/^user_overlays=/{print $2}' "$BOOT_ENV" | tail -n1 || true)"
NEW=""
# shellcheck disable=SC2086: word splitting over the overlay list is intended.
for item in $CURRENT; do
    [[ $item == "$OVERLAY_NAME" ]] || NEW+="$item "
done
NEW+="$OVERLAY_NAME"
NEW="$(echo "$NEW" | xargs)"
sed -i '/^user_overlays=/d' "$BOOT_ENV"
printf 'user_overlays=%s\n' "$NEW" >>"$BOOT_ENV"
grep -q "^user_overlays=.*${OVERLAY_NAME}" "$BOOT_ENV" \
    || { echo 'Failed to update user_overlays.' >&2; exit 1; }
echo "user_overlays=$NEW"

cat <<EOF

INSTALLATION COMPLETE (no reboot performed).

1. Shut down fully:   sudo poweroff
2. Remove board power for ~10 s with the PCIe FFC/HAT already connected
   (power the HAT's dedicated 5 V input if it has one).
3. Boot, then verify:  make board-pcie-status
   Expect: max-link-speed <0x02>, reset/power GPIOs, "pcie link up success",
   "PCIe speed of Gen2", and downstream devices in lspci.

Rollback backup: $BACKUP
To disable later: sudo ./setup.sh pcie --uninstall, then cold boot.
Full guide: docs/optional/pcie.md
EOF
