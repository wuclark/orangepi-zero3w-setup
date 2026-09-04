#!/usr/bin/env bash
# Purpose: Remove managed display, remote-access, linker, and delayed-module configuration.
# Platform: Orange Pi target board with repository-managed optional layers installed.
# Inputs: No command-line options; operates on fixed managed paths.
# Dependencies: Bash, root, systemd, ldconfig, and scripts/lib.sh.
# Writes: Disables services and removes managed configuration files; preserves runtime/module files for recovery.
# Safety: Does not remove packages or proprietary runtime files; delayed-load and recovery concerns remain explicit.
# Repeat: Safe to repeat because managed removal tolerates already-absent paths.
# Recovery: Restore timestamped backups under /var/backups/orangepi-zero3w-setup, then reboot only after review.
# Outputs: Cleanup actions and warnings describing preserved runtime/VPU files.
# Verification: Inspect systemd state, display configuration, and board-status after cleanup.
# Documentation: docs/development/development.md
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

systemctl disable --now x11vnc.service 2>/dev/null || true
systemctl disable pvr-late-load.service 2>/dev/null || true
systemctl stop lightdm.service 2>/dev/null || true

rm -f \
    /etc/systemd/system/x11vnc.service \
    /etc/systemd/system/pvr-late-load.service \
    /etc/X11/xorg.conf.d/10-sunxi-primary.conf \
    /etc/lightdm/lightdm.conf.d/20-orangepi-autologin.conf \
    /usr/local/sbin/Xorg-pvr \
    /etc/vulkan/icd.d/img_icd.json \
    /etc/ld.so.conf.d/pvr-ddk-24.2.conf

systemctl daemon-reload
ldconfig

warn "The runtime at /opt/pvr-ddk-24.2 and /opt/pvrsrvkm.ko was preserved for recovery."
warn "VPU files were installed into system runtime paths; restore their timestamped backup manually if needed."
warn "Restore prior configuration from /var/backups/$PROJECT_NAME if required, then reboot."
