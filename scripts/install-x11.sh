#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

TARGET_USER=""
FORCE_VIDEO="HDMI-A-1:1920x1080@60D"
while (($#)); do
    case "$1" in
        --user) TARGET_USER=${2:?}; shift 2 ;;
        --video) FORCE_VIDEO=${2:?}; shift 2 ;;
        --no-force-video) FORCE_VIDEO=""; shift ;;
        -h|--help) echo "Usage: sudo $0 [--user USER] [--video MODE|--no-force-video]"; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done
TARGET_USER=$(resolve_real_user "$TARGET_USER")
id "$TARGET_USER" >/dev/null 2>&1 || die "User does not exist: $TARGET_USER"

install -d -m 755 /etc/X11/xorg.conf.d /etc/lightdm/lightdm.conf.d
install -m 644 "$REPO_ROOT/config/10-sunxi-primary.conf" /etc/X11/xorg.conf.d/10-sunxi-primary.conf
install -m 755 "$REPO_ROOT/config/Xorg-pvr" /usr/local/sbin/Xorg-pvr

cat > /etc/lightdm/lightdm.conf.d/20-orangepi-autologin.conf <<EOF
[Seat:*]
autologin-user=$TARGET_USER
autologin-user-timeout=0
user-session=openbox
xserver-command=/usr/local/sbin/Xorg-pvr -core -nolisten tcp
EOF

if [[ -n $FORCE_VIDEO && -f /boot/armbianEnv.txt ]]; then
    if grep -q '^extraargs=' /boot/armbianEnv.txt; then
        if ! grep '^extraargs=' /boot/armbianEnv.txt | grep -q "video=$FORCE_VIDEO"; then
            sed -i "/^extraargs=/ s|$| video=$FORCE_VIDEO|" /boot/armbianEnv.txt
        fi
    else
        printf 'extraargs=video=%s\n' "$FORCE_VIDEO" >> /boot/armbianEnv.txt
    fi
fi

systemctl set-default graphical.target
systemctl enable lightdm
log "Configured Xorg card0 scanout, PowerVR DRI environment and LightDM autologin for $TARGET_USER."

