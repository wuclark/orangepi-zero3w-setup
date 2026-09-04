#!/usr/bin/env bash
# Purpose: Run one application with the isolated PowerVR EGL/GLES library environment.
# Platform: Orange Pi board/application session with the PowerVR DDK installed.
# Inputs: Command and arguments to execute; existing LD_LIBRARY_PATH/LIBGL_DRIVERS_PATH are appended.
# Dependencies: Bash and the target application plus /opt/pvr-ddk-24.2 managed libraries/DRI files.
# Writes: No files directly; the child application may write its own normal outputs.
# Safety: Scope changes to the child process and does not globally alter system library configuration.
# Repeat: Each invocation creates an independent child environment and is safe to repeat.
# Recovery: Exit the child application; remove no system files because this wrapper installs nothing.
# Outputs: The child application's stdout, stderr, and exit status.
# Verification: Use it with eglinfo, vkcube, or another documented PowerVR application test.
# Documentation: docs/optional/gpu/gpu.md
set -Eeuo pipefail

if (($# == 0)); then
    echo "Usage: $0 COMMAND [ARGUMENT ...]" >&2
    echo 'Runs one application with the isolated PowerVR EGL/GLES environment.' >&2
    exit 2
fi

export LD_LIBRARY_PATH="/opt/pvr-ddk-24.2/mesa/lib:/opt/pvr-ddk-24.2/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LIBGL_DRIVERS_PATH="/opt/pvr-ddk-24.2/mesa/dri${LIBGL_DRIVERS_PATH:+:$LIBGL_DRIVERS_PATH}"
exec "$@"
