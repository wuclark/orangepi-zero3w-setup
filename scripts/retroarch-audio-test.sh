#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root
DEVICE=${RETROARCH_AUDIO_DEVICE:-plughw:CARD=allwinnerhdmi,DEV=0}
command -v speaker-test >/dev/null 2>&1 || die 'speaker-test is missing; install alsa-utils first.'
printf 'Testing ALSA playback on %s for up to 8 seconds. Stop early with Ctrl-C.\n' "$DEVICE"
set +e
timeout 8s speaker-test -D "$DEVICE" -c 2 -r 48000 -F S16_LE -t wav -l 2
status=$?
set -e
if [[ $status -eq 124 ]]; then
    log 'Audio test reached its time limit; this is not an installer failure.'
else
    exit "$status"
fi
