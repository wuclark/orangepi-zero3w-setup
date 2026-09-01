#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

[[ ${1:---status} == --status ]] || die \
    "Use the board workflow: make board-npu-precheck/install/verify."
require_root
if [[ -e /dev/vipcore ]]; then
    log "NPU device detected at /dev/vipcore; runtime/workload support remains experimental."
else
    log "No /dev/vipcore device detected. NPU support remains untested."
fi
log "Collect evidence with scripts/collect-diagnostics.sh before adding an NPU installer."
