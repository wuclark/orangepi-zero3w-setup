#!/usr/bin/env bash
# Purpose: Install and configure localhost-bound WayVNC for the selected desktop user.
# Platform: Orange Pi board using Sway, labwc, or Weston session integration.
# Inputs: Optional --user; otherwise the invoking real user is selected.
# Dependencies: Bash, root, apt-get, wayvnc, systemd/session launcher files, and a valid user home.
# Writes: WayVNC config/marker under the user's home and the managed session launcher under /usr/local/libexec.
# Safety: Defaults to 127.0.0.1:5900 and does not expose the service on the LAN.
# Repeat: Preserves an existing WayVNC config and refreshes managed launcher/marker paths.
# Recovery: Remove the marker/config or uninstall the remote backend using the remote-access recovery guide.
# Outputs: Configuration log naming the user and localhost port.
# Verification: Enter a supported graphical session and run the WayVNC verification helper.
# Documentation: docs/guide/04-remote-access.md
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

TARGET_USER=""
while (($#)); do
    case "$1" in
        --user) TARGET_USER=${2:?}; shift 2;;
        -h|--help) echo "Usage: sudo $0 [--user USER]"; exit 0;;
        *) die "Unknown argument: $1";;
    esac
done
TARGET_USER=$(resolve_real_user "$TARGET_USER")
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
[[ -n $USER_HOME ]] || die "Cannot determine home directory for $TARGET_USER."

apt-get install -y wayvnc
install -d -m 755 /usr/local/libexec/orangepi-zero3w-setup
install -m 755 "$SCRIPT_DIR/orangepi-session-launch" \
    /usr/local/libexec/orangepi-zero3w-setup/session-launch
install -d -o "$TARGET_USER" -g "$TARGET_USER" -m 700 \
    "$USER_HOME/.config/wayvnc" "$USER_HOME/.config/orangepi-zero3w-setup"
if [[ ! -f "$USER_HOME/.config/wayvnc/config" ]]; then
    cat > "$USER_HOME/.config/wayvnc/config" <<'EOF'
# Managed by orangepi-zero3w-setup. SSH tunneling is the default access path.
address=127.0.0.1
port=5900
EOF
    chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/.config/wayvnc/config"
    chmod 600 "$USER_HOME/.config/wayvnc/config"
fi
touch "$USER_HOME/.config/orangepi-zero3w-setup/wayvnc-enabled"
chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/.config/orangepi-zero3w-setup/wayvnc-enabled"
chmod 600 "$USER_HOME/.config/orangepi-zero3w-setup/wayvnc-enabled"
log "wayvnc configured for $TARGET_USER on localhost TCP port 5900."
log "It starts automatically when that user enters a supported labwc, sway, or Weston session."
