#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo.' >&2; exit 1; }
status() { printf '%-28s %s\n' "$1:" "$2"; }
command_status() {
    if command -v "$2" >/dev/null 2>&1; then status "$1" "available ($(command -v "$2"))";
    else status "$1" 'missing'; fi
}
service_status() {
    local enabled active
    enabled=$(systemctl is-enabled "$2" 2>/dev/null || printf '%s' disabled/not-installed)
    active=$(systemctl is-active "$2" 2>/dev/null || printf '%s' inactive)
    status "$1" "enabled=$enabled active=$active"
}

echo "Orange Pi board status: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
status 'Board' "$(tr '\0' ' ' </proc/device-tree/compatible 2>/dev/null || echo unknown)"
status 'Kernel' "$(uname -r)"
status 'Architecture' "$(uname -m)"
status 'Uptime' "$(uptime -p 2>/dev/null || true)"
status 'Root filesystem' "$(df -hP / | awk 'NR==2 {print $3 " used / " $4 " available (" $5 ")"}')"
status 'Reboot required' "$([[ -e /var/run/reboot-required ]] && echo yes || echo no)"
status 'System state' "$(systemctl is-system-running 2>/dev/null || echo unavailable)"

printf '\n===== ACCELERATION =====\n'
status 'GPU module' "$(lsmod | awk '$1 == "pvrsrvkm" {print "loaded"; found=1} END {if (!found) print "not loaded"}')"
status 'GPU service' "$(systemctl is-active pvr-late-load.service 2>/dev/null || echo inactive)"
for node in /dev/dri/card0 /dev/dri/card1 /dev/dri/renderD128 /dev/cedar_dev /dev/vipcore; do
    status "$node" "$([[ -e $node ]] && echo present || echo absent)"
done
for firmware in /usr/lib/firmware/rgx.fw.36.56.104.183 /usr/lib/firmware/rgx.sh.36.56.104.183; do
    status "Firmware $(basename "$firmware")" "$([[ -r $firmware ]] && echo readable || echo missing)"
done
for library in /opt/pvr-ddk-24.2/lib/libVK_IMG.so /opt/pvr-ddk-24.2/lib/libGLESv2_PVR_MESA.so \
    /opt/pvr-ddk-24.2/mesa/dri/pvr_dri.so /usr/local/lib/npu/libVIPhal.so; do
    status "Library $(basename "$library")" "$([[ -e $library ]] && echo present || echo absent)"
done

printf '\n===== SERVICES AND DESKTOP =====\n'
status 'Default target' "$(systemctl get-default 2>/dev/null || echo unavailable)"
service_status 'LightDM' lightdm
service_status 'x11vnc' x11vnc.service
service_status 'Weston PVR' weston-pvr.service
status 'Desktop profile' "$(cat /etc/orangepi-zero3w-setup/state/desktop-profile 2>/dev/null || echo none)"
status 'Remote backend' "$(cat /etc/orangepi-zero3w-setup/state/remote-type 2>/dev/null || echo none)"

printf '\n===== TOOLS =====\n'
for tool in vulkaninfo eglinfo glxinfo gst-launch-1.0 sysbench fio iperf3; do
    command_status "$tool" "$tool"
done
if [[ -x /opt/orangepi-zero3w-setup/npu-test/bin/vpm_run ]]; then
    status 'vpm_run' 'installed (/opt/orangepi-zero3w-setup/npu-test/bin/vpm_run)'
else
    status 'vpm_run' 'not installed'
fi

printf '\n===== SETUP DATA =====\n'
status 'Setup config' "$([[ -f /etc/orangepi-zero3w-setup/config ]] && echo present || echo absent)"
status 'Embedded repository' "$([[ -d /opt/orangepi-zero3w-setup ]] && echo present || echo absent)"
status 'Vendor archives' "$(find /opt/orangepi-zero3w-setup/vendor-files -maxdepth 1 -type f -name '*.tar.gz' 2>/dev/null | wc -l) found in /opt/orangepi-zero3w-setup/vendor-files"
status 'Recent acceleration log' "$(ls -1t /var/log/orangepi-zero3w-setup/acceleration-progress.log* 2>/dev/null | head -n1 || echo none)"
status 'Recent validation log' "$(ls -1t /var/log/orangepi-zero3w-setup/board-validation-*.txt 2>/dev/null | head -n1 || echo none)"
status 'Recent benchmark log' "$(ls -1t /var/log/orangepi-zero3w-setup/*benchmark*.txt 2>/dev/null | head -n1 || echo none)"

echo
echo 'Read-only status report complete.'
