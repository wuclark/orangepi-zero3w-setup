#!/usr/bin/env bash
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
