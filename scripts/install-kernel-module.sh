#!/usr/bin/env bash
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

