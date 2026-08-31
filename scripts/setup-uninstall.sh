#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

"$SCRIPT_DIR/setup-reset.sh"
"$SCRIPT_DIR/uninstall.sh"
rm -rf -- /etc/orangepi-zero3w-setup
warn "Project-installed packages were not removed automatically. Review the package list before removing anything."
warn "PowerVR runtime/module files were preserved for recovery."
