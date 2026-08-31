#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

CONF=/etc/lightdm/lightdm.conf.d/50-orangepi-zero3w-setup.conf
if [[ -f $CONF ]] && grep -q 'managed by orangepi-zero3w-setup' "$CONF"; then
    rm -f "$CONF"
fi
if [[ -f /etc/orangepi-zero3w-setup/state/default-target ]]; then
    systemctl set-default "$(cat /etc/orangepi-zero3w-setup/state/default-target)"
else
    systemctl set-default multi-user.target
fi
systemctl disable lightdm 2>/dev/null || true
rm -f /etc/orangepi-zero3w-setup/state/desktop-profile \
    /etc/orangepi-zero3w-setup/state/remote-backend \
    /etc/orangepi-zero3w-setup/state/desktop-profile.previous \
    /etc/orangepi-zero3w-setup/state/remote-type
rm -f /usr/local/sbin/orangepi-session \
    /usr/local/libexec/orangepi-zero3w-setup/session-launch \
    /usr/share/xsessions/orangepi-{openbox,xfce,i3,icewm,fluxbox,enlightenment-x11}.desktop \
    /usr/share/wayland-sessions/orangepi-{sway,labwc,enlightenment-wayland}.desktop
log "Reset project-managed desktop and remote configuration. Installed packages were preserved."
