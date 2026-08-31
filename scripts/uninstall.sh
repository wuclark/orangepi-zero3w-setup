#!/usr/bin/env bash
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
