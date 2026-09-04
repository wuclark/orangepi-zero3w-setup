#!/usr/bin/env bash
# Purpose: Report installed board identity, setup state, services, and acceleration device presence.
# Platform: Orange Pi target board; read-only status helper.
# Inputs: Current device-tree, kernel, systemd, setup state/config, and device nodes.
# Dependencies: Bash, procfs/device-tree, systemd, lsmod, awk, and repository state paths.
# Writes: No persistent files; prints a concise status report to stdout.
# Safety: Does not install, enable, disable, modify, or reboot anything.
# Repeat: Safe to run repeatedly; values reflect current board state.
# Recovery: No recovery action is required; use the relevant layer guide for reported problems.
# Outputs: Board/kernel/configuration/service/desktop/remote/GPU/NPU status lines.
# Verification: Compare output with `make board-status` and layer-specific validation commands.
# Documentation: docs/development/development.md
set -Eeuo pipefail

echo "Board: $(tr '\0' ' ' </proc/device-tree/compatible 2>/dev/null || echo unknown)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Config: $([[ -f /etc/orangepi-zero3w-setup/config ]] && echo present || echo absent)"
echo "Default target: $(systemctl get-default 2>/dev/null || echo unavailable)"
echo "LightDM: $(systemctl is-enabled lightdm 2>/dev/null || echo disabled/not-installed)"
echo "Desktop profile: $(cat /etc/orangepi-zero3w-setup/state/desktop-profile 2>/dev/null || echo none)"
echo "Remote type: $(cat /etc/orangepi-zero3w-setup/state/remote-type 2>/dev/null || echo none)"
echo "x11vnc: $(systemctl is-enabled x11vnc 2>/dev/null || echo disabled/not-installed)"
echo "GPU module: $(lsmod 2>/dev/null | awk '$1 == "pvrsrvkm" {print "loaded"}' | head -n1)"
[[ -e /dev/vipcore ]] && echo "NPU device: present" || echo "NPU device: absent/untested"
