#!/usr/bin/env bash
# Purpose: Report ALSA cards, playback devices, and the known Allwinner HDMI device name.
# Platform: Orange Pi Zero 3W target board.
# Inputs: Current `/proc/asound` state and optional `aplay` availability.
# Dependencies: Bash, scripts/lib.sh, root, and optional alsa-utils/aplay.
# Writes: No persistent files; prints read-only audio diagnostics to stdout.
# Safety: Does not start playback, change mixer state, install packages, or reboot.
# Repeat: Safe to run repeatedly; output reflects the current kernel audio state.
# Recovery: No recovery action is required; install alsa-utils if the diagnostic is incomplete.
# Outputs: ALSA card/device listings and warnings for unavailable components.
# Verification: Confirm the expected `allwinnerhdmi` card appears on the target board.
# Documentation: docs/development/development.md
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

printf 'Orange Pi audio status: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '\n===== ALSA CARDS =====\n'
if [[ -r /proc/asound/cards ]]; then cat /proc/asound/cards; else echo 'WARN: /proc/asound/cards is unavailable.'; fi
printf '\n===== ALSA PLAYBACK DEVICES =====\n'
if command -v aplay >/dev/null 2>&1; then
    aplay -l || true
else
    echo 'WARN: aplay is missing; install alsa-utils.'
fi
printf '\n===== KNOWN DEVICES =====\n'
if command -v aplay >/dev/null 2>&1 && aplay -l 2>/dev/null | grep -qi allwinnerhdmi; then
    echo 'HDMI playback: default:CARD=allwinnerhdmi'
    echo 'Explicit device: plughw:CARD=allwinnerhdmi,DEV=0'
else
    echo 'WARN: allwinnerhdmi was not detected.'
fi
echo 'Read-only audio status complete; no playback test was run.'
