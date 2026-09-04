#!/usr/bin/env bash
# Purpose: Reset repository setup state and run the conservative legacy uninstall flow.
# Platform: Orange Pi target board with the repository setup installed.
# Inputs: No command-line options; uses the delegated reset/uninstall scripts.
# Dependencies: Bash, root, scripts/lib.sh, setup-reset.sh, and uninstall.sh.
# Writes: Removes /etc/orangepi-zero3w-setup and delegates managed service/config cleanup.
# Safety: Requires root; preserves PowerVR runtime/module files and does not remove packages automatically.
# Repeat: Managed cleanup is repeatable; missing files are tolerated by delegated removal steps.
# Recovery: Restore preserved configuration from /var/backups/orangepi-zero3w-setup before reboot.
# Outputs: Delegated reset/uninstall diagnostics and warnings about preserved components.
# Verification: Run setup-status or board-status and inspect services before any reboot.
# Documentation: docs/development/development.md
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

"$SCRIPT_DIR/setup-reset.sh"
"$SCRIPT_DIR/uninstall.sh"
rm -rf -- /etc/orangepi-zero3w-setup
warn "Project-installed packages were not removed automatically. Review the package list before removing anything."
warn "PowerVR runtime/module files were preserved for recovery."
