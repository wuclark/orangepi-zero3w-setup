#!/usr/bin/env bash
# Purpose: Install a vermagic-matched pvrsrvkm module with the required delayed-load service.
# Platform: Orange Pi Zero 3W AArch64 reference kernel and PowerVR DDK stack.
# Inputs: Required --module path to a built pvrsrvkm.ko.
# Dependencies: Bash, root, modinfo, systemd, matching running kernel, and repository service configuration.
# Writes: /opt/pvrsrvkm.ko and /etc/systemd/system/pvr-late-load.service; removes unsafe early-load configuration.
# Safety: Refuses mismatched vermagic and preserves delayed module loading; does not load the module or reboot.
# Repeat: Replaces the managed module/service and re-enables the same delayed-load unit.
# Recovery: Restore the prior module/service from the setup backup and retain UART recovery access.
# Outputs: Installation log and enabled delayed service state.
# Verification: Run board-gpu-abi-check before rebooting or using the GPU stack.
# Documentation: docs/optional/gpu/gpu.md
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

MODULE_PATH=""
while (($#)); do
    case "$1" in
        --module) MODULE_PATH=${2:?}; shift 2 ;;
        -h|--help) echo "Usage: sudo $0 --module PATH"; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

[[ -f $MODULE_PATH ]] || die "Module not found: $MODULE_PATH"
VERMAGIC=$(modinfo -F vermagic "$MODULE_PATH")
[[ $VERMAGIC == "$(uname -r)"* ]] || die "Module vermagic does not match the running kernel."

install -m 644 "$MODULE_PATH" /opt/pvrsrvkm.ko
install -m 644 "$REPO_ROOT/config/pvr-late-load.service" /etc/systemd/system/pvr-late-load.service

# Remove an unsafe early-load rule if an earlier experiment created it.
rm -f /etc/modules-load.d/pvrsrvkm.conf

systemctl daemon-reload
systemctl enable pvr-late-load.service
log "Installed delayed PowerVR module service. The module will not be placed in modules-load.d."
