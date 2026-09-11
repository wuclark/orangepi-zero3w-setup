#!/usr/bin/env bash
# Purpose: Produce a read-only PCIe, USB, and storage diagnostic report.
# Platform: Orange Pi Zero 3W (A733); root is recommended for dmesg/lspci detail
# but the script runs without root and notes restricted sections.
# Inputs: stdout only; no arguments are required.
# Writes: report output only; no boot, overlay, package, or device changes.
# Safety: does not install, modify, load, unload, restart, or reboot anything;
# safe on systems with or without the PCIe overlay installed.
# Repeat behavior: safe to run repeatedly and suitable for before/after cold-boot
# comparison; dmesg history reflects the current boot only.
# Recovery: a root-bridge-only lspci with missing-GPIO warnings means the overlay
# is absent or inactive; see docs/optional/pcie.md for install/rollback steps.
# Verification: compare the live-DT properties, kernel link lines, and lspci tree
# against the expected working values in docs/optional/pcie.md.
set -Eeuo pipefail

echo "Orange Pi PCIe status: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Kernel: $(uname -a)"
echo

echo '===== BOOT CONFIG ====='
if [[ -r /boot/armbianEnv.txt ]]; then
    grep -E '^(verbosity|fdtfile|overlay_prefix|user_overlays|extraargs)=' /boot/armbianEnv.txt || true
else
    echo '/boot/armbianEnv.txt: unreadable (Armbian-style boot layout expected)'
fi
if [[ -e /boot/overlay-user/sun60iw2-pcie-gen2.dtbo ]]; then
    echo 'Overlay file: present (/boot/overlay-user/sun60iw2-pcie-gen2.dtbo)'
    ls -l /boot/overlay-user/sun60iw2-pcie-gen2.dtbo || true
else
    echo 'Overlay file: absent (/boot/overlay-user/sun60iw2-pcie-gen2.dtbo)'
fi
echo

echo '===== LIVE PCIE DEVICE TREE ====='
if command -v dtc >/dev/null 2>&1 && [[ -d /proc/device-tree/soc@3000000/pcie@6000000 ]]; then
    dtc -I fs -O dts /proc/device-tree 2>/dev/null \
        | sed -n '/pcie@6000000 {/,/legacy-interrupt-controller {/p' \
        | grep -E 'max-link-speed|num-lanes|reset-gpios|power-gpios|wake-gpios|compatible|status' \
        || echo '(PCIe properties not found in live tree)'
else
    echo '(dtc missing or live PCIe node absent; install device-tree-compiler to inspect)'
fi
echo

echo '===== PCIE KERNEL LOG (current boot) ====='
if dmesg 2>/dev/null | grep -Ei 'pcie|power-gpios|reset-gpios|speed change|speed of|link' | head -n 40; then
    true
else
    echo '(no PCIe lines in dmesg, or dmesg is restricted; try with sudo)'
fi
echo

echo '===== PCI DEVICES ====='
if command -v lspci >/dev/null 2>&1; then
    # lspci needs root for full details on some systems; -nn works either way.
    (sudo -n lspci -nn 2>/dev/null || lspci -nn 2>/dev/null) || echo '(lspci failed)'
else
    echo '(lspci missing; install pciutils)'
fi
echo

echo '===== PCI TREE ====='
if command -v lspci >/dev/null 2>&1; then
    (sudo -n lspci -tv 2>/dev/null || lspci -tv 2>/dev/null) || echo '(lspci tree failed)'
fi
echo

echo '===== USB TREE ====='
if command -v lsusb >/dev/null 2>&1; then
    lsusb -t 2>/dev/null || echo '(lsusb tree failed)'
else
    echo '(lsusb missing; install usbutils)'
fi
echo

echo '===== STORAGE ====='
if command -v lsblk >/dev/null 2>&1; then
    lsblk -o NAME,MODEL,SIZE,TRAN 2>/dev/null || echo '(lsblk failed)'
else
    echo '(lsblk missing)'
fi
echo

echo 'Expected when the overlay is active on the tested HAT: max-link-speed'
echo '<0x02> with PD22/PD23 reset/power GPIOs, "pcie link up success" and'
echo '"PCIe speed of Gen2" in dmesg, and an ASM1182e switch plus VIA VL805/806'
echo 'controller in lspci. Root-bridge-only output means the link did not train.'
echo
echo 'Read-only PCIe report complete.'
