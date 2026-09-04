#!/usr/bin/env bash
# Purpose: Convenience wrapper for the legacy first-run Armbian bootstrap flow.
# Platform: Fresh Orange Pi Zero 3W AArch64 system with staged vendor inputs.
# Inputs: Optional bootstrap arguments; reads ./vendor-root and ./vendor-files/pvrsrvkm.ko from the repository.
# Dependencies: Bash, sudo/root, and scripts/armbian-bootstrap.sh with its dependencies.
# Writes: Delegates all system writes to armbian-bootstrap.sh; this wrapper writes no files itself.
# Safety: Requires the matching staged module and vendor root; does not extract archives or reboot directly.
# Repeat: Delegates repeat behavior and backup creation to armbian-bootstrap.sh.
# Recovery: Use the bootstrap backup and recovery procedure in docs/guide/05-recovery.md.
# Outputs: The delegated bootstrap installation output and exit status.
# Verification: Verify the completed installation using the board validation targets.
# Documentation: docs/development/development.md
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
