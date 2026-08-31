#!/usr/bin/env bash
set -Eeuo pipefail

# Convenience entrypoint for a freshly installed Armbian system.
# Place the extracted vendor root at ./vendor-root and the matching module at
# ./vendor-files/pvrsrvkm.ko, then run this script with sudo.

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
TARGET_USER=${SUDO_USER:-orangepi}

exec "$SCRIPT_DIR/armbian-bootstrap.sh" \
    --vendor-root "$REPO_ROOT/vendor-root" \
    --module "$REPO_ROOT/vendor-files/pvrsrvkm.ko" \
    --user "$TARGET_USER" \
    "$@"

