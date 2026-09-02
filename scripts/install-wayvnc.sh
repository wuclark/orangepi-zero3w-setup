#!/usr/bin/env bash
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
log "It starts automatically when that user enters a supported labwc or sway session."
