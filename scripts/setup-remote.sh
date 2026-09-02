#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

BACKEND=
TARGET_USER=
usage() {
    cat <<'EOF'
Usage: sudo ./setup.sh remote --backend BACKEND [--user USER]

Backends: x11vnc, wayvnc, tigervnc

Remote services are separate from desktop installation. x11vnc and wayvnc
mirror an active session; TigerVNC creates a separate virtual X11 desktop.
Services use SSH tunneling by default. See docs/remote/ssh-tunneling.md.
EOF
}
while (($#)); do
    case "$1" in
        --backend) BACKEND=${2:?missing backend}; shift 2 ;;
        --user) TARGET_USER=${2:?missing user}; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done
require_root
TARGET_USER=$(resolve_real_user "$TARGET_USER")
case "$BACKEND" in
    x11vnc) exec "$SCRIPT_DIR/install-x11vnc.sh" --user "$TARGET_USER" ;;
    wayvnc) exec "$SCRIPT_DIR/install-wayvnc.sh" --user "$TARGET_USER" ;;
    tigervnc)
        apt-get install -y tigervnc-standalone-server tigervnc-tools
        log "TigerVNC installed; no service was exposed."
        ;;
    *) die "Unknown backend: $BACKEND" ;;
esac
