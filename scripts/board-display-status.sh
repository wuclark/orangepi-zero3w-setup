#!/usr/bin/env bash
# Purpose: Report DRM connector state, modes, and the current X11 display output.
# Platform: Orange Pi Zero 3W target board with a non-root desktop user.
# Inputs: DISPLAY_STATUS_USER or the resolved login user, DRM sysfs, and X11 :0 state.
# Dependencies: Bash, scripts/lib.sh, root, getent, runuser, and optional xrandr.
# Writes: No persistent files; prints read-only display diagnostics to stdout.
# Safety: Refuses to inspect a root desktop session and never changes display configuration.
# Repeat: Safe to run repeatedly; results reflect current connectors and session state.
# Recovery: No recovery action is required; use the display guide for disconnected outputs.
# Outputs: DRM connector/mode information, X11 output status, and interpretation hints.
# Verification: Confirm expected HDMI/DP connector and X11 output state on the target board.
# Documentation: docs/guide/03-desktop-sessions.md
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root
TARGET_USER=${DISPLAY_STATUS_USER:-$(resolve_real_user)}
[[ $TARGET_USER != root ]] || die 'Refusing to inspect a root desktop session.'
id "$TARGET_USER" >/dev/null 2>&1 || die "User does not exist: $TARGET_USER"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

printf 'Orange Pi display status: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'target_user=%s\n' "$TARGET_USER"
printf '\n===== DRM CONNECTORS =====\n'
for connector in /sys/class/drm/*-*; do
    [[ -f $connector/status ]] || continue
    name=$(basename -- "$connector")
    printf '%-12s status=%s' "$name" "$(cat "$connector/status")"
    [[ -r $connector/modes ]] && printf ' modes=%s' "$(paste -sd, "$connector/modes")"
    printf '\n'
done

printf '\n===== X11 DISPLAY :0 =====\n'
if [[ -S /tmp/.X11-unix/X0 ]] && command -v xrandr >/dev/null 2>&1; then
    xrandr_output=$(runuser -u "$TARGET_USER" -- env HOME="$USER_HOME" DISPLAY=:0 xrandr --query 2>&1 || true)
    if grep -q ' connected' <<<"$xrandr_output"; then
        grep -E '^(HDMI|DP|eDP|DVI|DisplayPort)-[^ ]+ (connected|disconnected)' <<<"$xrandr_output" || true
        pass='X11 display query succeeded'
        printf 'PASS: %s\n' "$pass"
    else
        printf '%s\n' "$xrandr_output"
        echo 'WARN: X11 display query did not report a connected output.'
    fi
else
    echo 'WARN: X11 :0 or xrandr is unavailable; inspect DRM connector state above.'
fi

cat <<'EOF'

USB-C DP interpretation:
  DP-1 connected    USB-C DisplayPort output is detected by the running stack.
  DP-1 disconnected The connector exists, but no active DP sink was detected.
  HDMI-1 connected  HDMI output is active.
EOF
echo 'Read-only display status complete.'
