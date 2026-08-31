#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

MODULE_PATH=""
ALLOW_UNTESTED=no

while (($#)); do
    case "$1" in
        --module) MODULE_PATH=${2:?}; shift 2 ;;
        --allow-untested) ALLOW_UNTESTED=yes; shift ;;
        -h|--help)
            echo "Usage: $0 --module PATH [--allow-untested]"
            exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

[[ $(uname -m) == aarch64 ]] || die "This installer requires aarch64."
[[ -r /etc/os-release ]] || die "Cannot identify the operating system."

RUNNING_KERNEL=$(uname -r)
if [[ $RUNNING_KERNEL != "$REFERENCE_KERNEL" ]]; then
    if [[ $ALLOW_UNTESTED != yes ]]; then
        die "Unsupported kernel $RUNNING_KERNEL; tested kernel is $REFERENCE_KERNEL. Use --allow-untested only after building a matching module."
    fi
    warn "Continuing on untested kernel $RUNNING_KERNEL."
fi

[[ -n $MODULE_PATH && -f $MODULE_PATH ]] || die "Supply the matching pvrsrvkm.ko with --module PATH."
require_command modinfo

VERMAGIC=$(modinfo -F vermagic "$MODULE_PATH")
[[ $VERMAGIC == "$RUNNING_KERNEL"* ]] || die "Module vermagic '$VERMAGIC' does not match '$RUNNING_KERNEL'."

MODULE_NAME=$(modinfo -F name "$MODULE_PATH")
[[ $MODULE_NAME == pvrsrvkm ]] || die "Expected module name pvrsrvkm, got '$MODULE_NAME'."

if [[ -r /proc/device-tree/compatible ]]; then
    COMPATIBLE=$(tr '\0' '\n' < /proc/device-tree/compatible || true)
    if ! grep -Eqi 'sun60|a733|orangepi.*zero.*3w' <<<"$COMPATIBLE"; then
        warn "Device-tree compatible string was not recognized; inspect before publishing support for this board."
    fi
fi

log "Preflight passed: arch=$(uname -m), kernel=$RUNNING_KERNEL, module=$MODULE_NAME."

