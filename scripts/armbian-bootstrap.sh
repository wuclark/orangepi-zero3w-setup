#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
source "$SCRIPT_DIR/lib.sh"

VENDOR_ROOT=""
MODULE_PATH=""
FIRMWARE_DIR=""
TARGET_USER=""
FORCE_VIDEO="HDMI-A-1:1920x1080@60D"
ALLOW_UNTESTED=no
RUN_APT_UPDATE=no

usage() {
    cat <<EOF
Usage: sudo $0 --vendor-root ROOT --module FILE [options]

Options:
  --firmware-dir DIR     Override vendor firmware location
  --user USER            Desktop/autologin user (default: invoking user)
  --video MODE           Forced DRM mode (default: $FORCE_VIDEO)
  --no-force-video       Do not edit /boot/armbianEnv.txt
  --allow-untested       Permit a kernel other than the reference kernel
  --update               Explicitly refresh apt metadata before package installs
EOF
}

while (($#)); do
    case "$1" in
        --vendor-root) VENDOR_ROOT=${2:?}; shift 2 ;;
        --module) MODULE_PATH=${2:?}; shift 2 ;;
        --firmware-dir) FIRMWARE_DIR=${2:?}; shift 2 ;;
        --user) TARGET_USER=${2:?}; shift 2 ;;
        --video) FORCE_VIDEO=${2:?}; shift 2 ;;
        --no-force-video) FORCE_VIDEO=""; shift ;;
        --allow-untested) ALLOW_UNTESTED=yes; shift ;;
        --update) RUN_APT_UPDATE=yes; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

require_root

[[ -d $VENDOR_ROOT ]] || die "Supply --vendor-root pointing to the extracted vendor filesystem."
[[ -f $MODULE_PATH ]] || die "Supply --module pointing to the matching pvrsrvkm.ko."
TARGET_USER=$(resolve_real_user "$TARGET_USER")

PREFLIGHT_ARGS=(--module "$MODULE_PATH")
[[ $ALLOW_UNTESTED == yes ]] && PREFLIGHT_ARGS+=(--allow-untested)
"$SCRIPT_DIR/preflight.sh" "${PREFLIGHT_ARGS[@]}"

BACKUP_ROOT="/var/backups/$PROJECT_NAME/$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 700 "$BACKUP_ROOT"
for file in \
    /boot/armbianEnv.txt \
    /etc/X11/xorg.conf.d/10-sunxi-primary.conf \
    /etc/lightdm/lightdm.conf.d/20-orangepi-autologin.conf \
    /etc/systemd/system/pvr-late-load.service \
    /usr/local/sbin/Xorg-pvr \
    /etc/vulkan/icd.d/img_icd.json
do
    backup_file "$file" "$BACKUP_ROOT"
done

log "Installing Debian dependencies."
export DEBIAN_FRONTEND=noninteractive
[[ $RUN_APT_UPDATE == yes ]] && apt-get update
apt-get install -y \
    libdrm2 libx11-6 libx11-xcb1 libxcb1 \
    libxcb-dri2-0 libxcb-dri3-0 libxcb-present0 libxcb-xfixes0 \
    libxcb-sync1 libxcb-randr0 libxcb-shm0 libxshmfence1 \
    libvulkan1 vulkan-tools \
    xserver-xorg-core xserver-xorg-input-libinput xinit \
    x11-utils x11-xserver-utils lightdm lightdm-gtk-greeter \
    openbox xterm dbus-x11 mesa-utils x11vnc strace

USERSPACE_ARGS=(--vendor-root "$VENDOR_ROOT")
[[ -n $FIRMWARE_DIR ]] && USERSPACE_ARGS+=(--firmware-dir "$FIRMWARE_DIR")
"$SCRIPT_DIR/install-userspace.sh" "${USERSPACE_ARGS[@]}"
"$SCRIPT_DIR/install-kernel-module.sh" --module "$MODULE_PATH"

X11_ARGS=(--user "$TARGET_USER")
if [[ -n $FORCE_VIDEO ]]; then
    X11_ARGS+=(--video "$FORCE_VIDEO")
else
    X11_ARGS+=(--no-force-video)
fi
"$SCRIPT_DIR/install-x11.sh" "${X11_ARGS[@]}"

cat > "$BACKUP_ROOT/install-info.txt" <<EOF
installed_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
kernel=$(uname -r)
architecture=$(uname -m)
target_user=$TARGET_USER
vendor_root=$VENDOR_ROOT
module_source=$MODULE_PATH
module_sha256=$(sha256sum /opt/pvrsrvkm.ko | awk '{print $1}')
EOF

log "Installation complete. Backup: $BACKUP_ROOT"
log "Reboot, wait about 60 seconds, then run: $REPO_ROOT/scripts/verify.sh"
