#!/usr/bin/env bash
# Purpose: Report NPU device presence while directing installation/verification to the board workflow.
# Platform: Orange Pi Zero 3W AArch64 target board; NPU support remains experimental.
# Inputs: Only the default --status action is accepted.
# Dependencies: Bash, scripts/lib.sh, root, and the /dev/vipcore device check.
# Writes: No persistent files; emits read-only NPU status and evidence guidance.
# Safety: Does not install drivers, load modules, run workloads, or claim NPU support from device presence alone.
# Repeat: Safe to run repeatedly; output reflects the current device node state.
# Recovery: No recovery action; follow the NPU guide and collect diagnostics before changes.
# Outputs: Device presence message and the supported board workflow reminder.
# Verification: Use the board NPU precheck/install/verify targets and sanitized diagnostics.
# Documentation: docs/optional/npu.md
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
