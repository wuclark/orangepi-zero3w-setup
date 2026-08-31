#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

[[ ${1:---status} == --status ]] || die \
    "VPU installation is not implemented until a real-board media runtime is validated."
require_root
if [[ -e /dev/video0 ]]; then
    log "Video device detected at /dev/video0; VPU acceleration remains untested."
else
    log "No /dev/video0 device detected. VPU support remains untested."
fi
log "Collect evidence with scripts/collect-diagnostics.sh before adding a VPU installer."
