#!/usr/bin/env bash
# Purpose: Install one optional remote-display backend for the selected desktop.
# Platform: Debian/Armbian board image with an existing desktop session.
# Inputs: --backend x11vnc, wayvnc, or tigervnc; optional non-root --user.
# Writes: backend packages, service configuration, and project state.
# Safety: services default to SSH-tunneled/local access; no public exposure is added.
# Repeat behavior: backend installation is delegated to its idempotent installer.
# Recovery: use setup-reset.sh and the backend-specific uninstall/recovery guide.
# Verification: run remote-status, board-status, and the backend verification target.
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
    x11vnc|wayvnc)
        if "$SCRIPT_DIR/install-$BACKEND.sh" --user "$TARGET_USER"; then
            manifest_record "remote.$BACKEND" "sudo make remote-$BACKEND REMOTE_USER=$TARGET_USER"
        else
            exit 1
        fi
        ;;
    tigervnc)
        if apt-get install -y tigervnc-standalone-server tigervnc-tools; then
            manifest_record remote.tigervnc "sudo make remote-tigervnc REMOTE_USER=$TARGET_USER"
        else
            exit 1
        fi
        log "TigerVNC installed; no service was exposed."
        ;;
    *) die "Unknown backend: $BACKEND" ;;
esac
