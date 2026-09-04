#!/usr/bin/env bash
# Purpose: Report VPU status or dispatch the board VPU install/verify workflow.
# Platform: Orange Pi Zero 3W on the supported A733 board image.
# Inputs: Optional --status, --install, or --verify action; defaults to --status.
# Dependencies: Bash and scripts/lib.sh; install/verify actions require the board workflow.
# Writes: Status writes only stdout; dispatched install actions may modify board system paths.
# Safety: Requires root; this wrapper does not extract archives, install packages, or reboot.
# Repeat: Status is read-only; install and verify behavior is owned by the dispatched workflow.
# Recovery: Follow the VPU recovery instructions in docs/guide/05-recovery.md.
# Outputs: VPU status or the dispatched workflow's result and diagnostics.
# Verification: Use --verify or `sudo make board-vpu-verify` on the target board.
# Documentation: docs/optional/vpu.md
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

require_root
case ${1:---status} in
--status)
    ;;
--install)
    exec "$SCRIPT_DIR/board-acceleration-workflow.sh" --layer vpu --action install --yes
    ;;
--verify)
    exec "$SCRIPT_DIR/board-acceleration-workflow.sh" --layer vpu --action verify
    ;;
*)
    die "Usage: sudo ./setup.sh vpu [--status|--install|--verify]"
    ;;
esac
if [[ -e /dev/video0 ]]; then
    log "Video device detected at /dev/video0."
else
    log "No /dev/video0 device detected; Cedar/OMX may still be available."
fi
log "Use --install for board-side userspace installation and --verify for decode tests."
