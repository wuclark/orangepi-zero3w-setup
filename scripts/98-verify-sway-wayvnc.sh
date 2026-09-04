#!/usr/bin/env bash
# Purpose: Verify the expected Sway, LightDM, WayVNC, and Wayland session state.
# Platform: Orange Pi Zero 3W board running the repository's Sway/WayVNC profile.
# Inputs: Current user environment, process table, systemd state, and Wayland runtime directory.
# Dependencies: Bash, pgrep, systemctl, find, and the active graphical session.
# Writes: No persistent files; prints individual checks and a summary to stdout.
# Safety: Read-only diagnostic helper; it does not install, configure, stop, or reboot services.
# Repeat: Safe to run repeatedly; results reflect the current session state.
# Recovery: This script does not repair failures; follow docs/guide/04-remote-access.md.
# Outputs: PASS/FAIL lines and a nonzero exit status when any check fails.
# Verification: Run after the Sway/WayVNC setup and confirm all checks pass.
# Documentation: docs/guide/04-remote-access.md
set -Eeuo pipefail

passed=0
failed=0
check() {
    local label=$1; shift
    if "$@" >/dev/null 2>&1; then
        echo "PASS  $label"
        ((passed+=1))
    else
        echo "FAIL  $label"
        ((failed+=1))
    fi
}

check 'Sway process is running' pgrep -x sway
check 'LightDM is active' systemctl is-active --quiet lightdm.service
check 'WayVNC is enabled' test -f "$HOME/.config/orangepi-zero3w-setup/wayvnc-enabled"
check 'WayVNC process is running' pgrep -x wayvnc
check 'Wayland socket exists' bash -c 'find "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" -maxdepth 1 -type s -name "wayland-*" | grep -q .'

echo
echo "Summary: $passed passed, $failed failed"
((failed == 0))
