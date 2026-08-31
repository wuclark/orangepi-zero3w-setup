#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

[[ ${1:---status} == --status ]] || die \
    "NPU installation is not implemented until a real-board runtime is validated."
require_root
if [[ -e /dev/vipcore ]]; then
    log "NPU device detected at /dev/vipcore, but no supported runtime is claimed."
else
    log "No /dev/vipcore device detected. NPU support remains untested."
fi
log "Collect evidence with scripts/collect-diagnostics.sh before adding an NPU installer."
