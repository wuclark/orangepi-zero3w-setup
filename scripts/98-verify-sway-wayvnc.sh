#!/usr/bin/env bash
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
