#!/usr/bin/env bash
# Purpose: Build and install the upstream hid-multitouch module for the tested
#   vendor kernel so USB multitouch panels expose per-contact tracking.
# Platform: Orange Pi Zero 3W on aarch64 running exactly
#   6.6.98-vendor-sun60iw2 with matching prepared kernel headers; requires root.
# Inputs: optional --update (refresh apt first) and --uninstall. No other options.
# Dependencies: Bash, root, matching linux-headers-vendor-sun60iw2, build tools
#   (build-essential, curl, libelf-dev, bc, kmod), and network access to the
#   pinned upstream v6.6.98 sources (SHA-256 verified before building).
# Writes: build tree under mktemp dir (kept for reference), module file at
#   /lib/modules/<kernel>/updates/hid-multitouch.ko, refreshed depmod indexes,
#   loaded hid_multitouch module, and the board replay manifest receipt.
# Safety: narrow kernel guard aborts on any other kernel; sources are pinned by
#   SHA-256 and the compiled module's vermagic is checked before install; the
#   running kernel itself is never replaced and no reboot is performed.
# Repeat behavior: idempotent; a previous module at the target path is backed
#   up into the build directory before replacement.
# Recovery: --uninstall unloads (when unused) and removes the module file, then
#   refreshes depmod; reconnect USB touch to return to the stock driver.
# Verification: sudo modinfo -F vermagic hid_multitouch, then reconnect the
#   touch USB connection and check sudo evtest for ABS_MT_SLOT/TRACKING_ID and
#   multiple simultaneous contacts.
# Documentation: docs/optional/touch-rightclick.md ("True multitouch" section).
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

EXPECTED_KERNEL=6.6.98-vendor-sun60iw2
EXPECTED_SOURCE_URL='https://raw.githubusercontent.com/gregkh/linux/v6.6.98/drivers/hid'
# SHA-256 of the upstream v6.6.98 files, independently verified 2026-09-14.
EXPECTED_MULTITOUCH_SHA256=08164dc384153f0109c20652aa3e44f6aa5136e0d5b767bb8c384bc4ae4aff2c
EXPECTED_IDS_SHA256=1de79a5d8a5152c579e3a763c0201bc1faa87d3d2fa499b6447748e209e65653
MODULE_NAME=hid_multitouch
MODULE_FILE=hid-multitouch.ko
APT_UPDATE=no
ACTION=install

usage() {
    cat <<'EOF'
Usage: sudo ./setup.sh touch-multitouch [--update|--uninstall]

Builds upstream hid-multitouch v6.6.98 against the running kernel's headers
and installs it so USB multitouch panels (e.g. WaveShare WS170120) expose
per-contact tracking instead of single-touch only.

Targets exactly 6.6.98-vendor-sun60iw2 on aarch64 and aborts otherwise. Uses
the existing apt cache unless --update is passed. Never replaces the kernel
and never reboots; reconnect the touch USB connection after install and verify
with sudo evtest.
EOF
}

while (($#)); do
    case "$1" in
        --update) APT_UPDATE=yes; shift ;;
        --uninstall) ACTION=uninstall; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done
require_root

KERNEL=$(uname -r)
TARGET="/lib/modules/$KERNEL/updates/$MODULE_FILE"

if [[ $ACTION == uninstall ]]; then
    modprobe -r "$MODULE_NAME" 2>/dev/null || warn "Module still in use or not loaded; continuing with file removal."
    rm -f "$TARGET"
    if command -v depmod >/dev/null 2>&1; then
        depmod -a "$KERNEL"
    fi
    manifest_delete input.multitouch
    log "Removed $MODULE_FILE. Reconnect touch USB to return to the stock driver."
    exit 0
fi

[[ $(uname -m) == aarch64 ]] || die "This installer targets aarch64; detected $(uname -m)."
[[ $KERNEL == "$EXPECTED_KERNEL" ]] || die "This installer targets exactly $EXPECTED_KERNEL; running $KERNEL. Do not install a module built for another kernel."

if [[ $APT_UPDATE == yes ]]; then
    apt-get update
fi
export DEBIAN_FRONTEND=noninteractive
# The metapackage name tracks the vendor kernel; install from cache when present.
apt-get install -y build-essential curl libelf-dev bc kmod "linux-headers-vendor-sun60iw2" || \
    die "Build prerequisites unavailable from the apt cache; rerun with --update."

HEADERS="/lib/modules/$KERNEL/build"
[[ -r $HEADERS/Makefile && -r $HEADERS/Module.symvers ]] || \
    die "Prepared headers missing ($HEADERS/Makefile or Module.symvers). Install matching headers first."

WORK=$(mktemp -d -t zero3w-hid-multitouch.XXXXXXXX)
log "Build directory (kept for reference): $WORK"
cd "$WORK"
curl --fail --location --retry 3 "$EXPECTED_SOURCE_URL/hid-multitouch.c" -o hid-multitouch.c
curl --fail --location --retry 3 "$EXPECTED_SOURCE_URL/hid-ids.h" -o hid-ids.h
printf '%s  %s\n' "$EXPECTED_MULTITOUCH_SHA256" hid-multitouch.c >SHA256SUMS
printf '%s  %s\n' "$EXPECTED_IDS_SHA256" hid-ids.h >>SHA256SUMS
sha256sum -c SHA256SUMS
printf '%s\n' 'obj-m := hid-multitouch.o' >Makefile
make -C "$HEADERS" M="$WORK" -j"$(nproc)" modules

VERMAGIC=$(modinfo -F vermagic ./"$MODULE_FILE")
[[ $VERMAGIC == "$KERNEL "* ]] || die "Unexpected module version: $VERMAGIC"
log "Module version: $VERMAGIC"
if [[ -e $TARGET ]]; then
    cp -- "$TARGET" "$WORK/$MODULE_FILE.previous"
    log "Previous module backed up in $WORK"
fi
install -D -m 0644 "$MODULE_FILE" "$TARGET"
depmod -a "$KERNEL"
modprobe "$MODULE_NAME"
manifest_record input.multitouch 'sudo make board-touch-multitouch-install'
log "Multitouch module installed and loaded."
log "Reconnect only the touchscreen USB data connection, then verify: sudo evtest"
log "Expect ABS_MT_SLOT/TRACKING_ID and multiple simultaneous contacts."
