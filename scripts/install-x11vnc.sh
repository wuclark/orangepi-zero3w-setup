#!/usr/bin/env bash
# Purpose: Install and enable x11vnc for the DRM-backed Xorg desktop.
# Platform: Orange Pi board using the repository's LightDM/X11 profile.
# Inputs: Optional --user and explicit --listen-lan network exposure option.
# Dependencies: Bash, root, apt-get, x11vnc, LightDM/Xorg, systemd, and an interactive VNC password prompt.
# Writes: User VNC password/config, MOTD tunnel helper, and /etc/systemd/system/x11vnc.service.
# Safety: Defaults to localhost; --listen-lan exposes port 5900 and must be an intentional choice.
# Repeat: Preserves an existing password, refreshes the managed service, and enables it without forced reboot.
# Recovery: Disable/remove x11vnc and restore the prior LightDM/X11 configuration using the remote guide.
# Outputs: Service configuration/status logs and the selected listen address.
# Verification: Confirm the service is active and use an SSH tunnel by default.
# Documentation: docs/guide/04-remote-access.md
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

TARGET_USER=""
LISTEN_ADDRESS=127.0.0.1
while (($#)); do
    case "$1" in
        --user) TARGET_USER=${2:?}; shift 2 ;;
        --listen-lan) LISTEN_ADDRESS=0.0.0.0; shift ;;
        -h|--help) echo "Usage: sudo $0 [--user USER] [--listen-lan]"; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done
TARGET_USER=$(resolve_real_user "$TARGET_USER")
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
[[ -n $USER_HOME ]] || die "Cannot determine home directory for $TARGET_USER."

apt-get install -y x11vnc
install -d -o "$TARGET_USER" -g "$TARGET_USER" -m 700 "$USER_HOME/.vnc"

if [[ ! -f $USER_HOME/.vnc/passwd ]]; then
    log "Set the VNC password for $TARGET_USER."
    runuser -u "$TARGET_USER" -- x11vnc -storepasswd "$USER_HOME/.vnc/passwd"
fi
chmod 600 "$USER_HOME/.vnc/passwd"
chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/.vnc/passwd"
install -m 0755 "$SCRIPT_DIR/../config/95-zero3w-vnc-tunnel" \
    /etc/update-motd.d/95-zero3w-vnc-tunnel

cat > /etc/systemd/system/x11vnc.service <<EOF
[Unit]
Description=x11vnc for the DRM-backed Xorg desktop
After=lightdm.service network-online.target
Wants=lightdm.service network-online.target

[Service]
Type=simple
User=$TARGET_USER
Group=$TARGET_USER
ExecStartPre=/bin/sh -c 'until test -S /tmp/.X11-unix/X0; do sleep 1; done'
ExecStart=/usr/bin/x11vnc -display :0 -auth guess -forever -shared -rfbauth $USER_HOME/.vnc/passwd -rfbport 5900 -listen $LISTEN_ADDRESS -noxdamage -repeat
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical.target
EOF

systemctl daemon-reload
systemctl enable x11vnc.service
if [[ -S /tmp/.X11-unix/X0 ]]; then
    systemctl start x11vnc.service
    log "x11vnc started on $LISTEN_ADDRESS TCP port 5900. Use SSH tunneling by default."
else
    log "x11vnc enabled and will start after LightDM creates display :0 on reboot."
fi
