#!/usr/bin/env bash
set -Eeuo pipefail

if (($# == 0)); then
    echo "Usage: $0 COMMAND [ARGUMENT ...]" >&2
    echo 'Runs one application with the isolated PowerVR EGL/GLES environment.' >&2
    exit 2
fi

export LD_LIBRARY_PATH="/opt/pvr-ddk-24.2/mesa/lib:/opt/pvr-ddk-24.2/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LIBGL_DRIVERS_PATH="/opt/pvr-ddk-24.2/mesa/dri${LIBGL_DRIVERS_PATH:+:$LIBGL_DRIVERS_PATH}"
exec "$@"
