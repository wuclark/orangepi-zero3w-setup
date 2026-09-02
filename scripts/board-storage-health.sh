#!/usr/bin/env bash
set -Eeuo pipefail

OUTPUT=${OUTPUT:-/var/log/orangepi-zero3w-setup/storage-health-$(date -u +%Y%m%dT%H%M%SZ).txt}
install -d -m 755 "$(dirname "$OUTPUT")"
exec > >(tee "$OUTPUT") 2>&1

echo "Orange Pi storage health: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
uname -a
printf '\n===== MOUNTS AND SPACE =====\n'
findmnt -rno TARGET,SOURCE,FSTYPE,OPTIONS 2>/dev/null || true
df -hT 2>/dev/null || true

printf '\n===== BLOCK DEVICES =====\n'
if command -v lsblk >/dev/null 2>&1; then
    lsblk -e 7 -o NAME,PATH,TYPE,SIZE,FSTYPE,LABEL,MOUNTPOINTS,ROTA,RO 2>/dev/null || true
else
    echo 'lsblk: missing'
fi

printf '\n===== MMC HEALTH =====\n'
found_mmc=no
for device in /sys/block/mmcblk*; do
    [[ -d $device ]] || continue
    found_mmc=yes
    name=${device##*/}
    printf '%s\n' "[$name]"
    for field in life_time pre_eol_info fwrev hwrev manfid name ocr serial; do
        if [[ -r $device/device/$field ]]; then
            printf '%s=%s\n' "$field" "$(<"$device/device/$field")"
        fi
    done
done
[[ $found_mmc == yes ]] || echo 'No MMC health data exposed by the kernel.'

printf '\n===== DEVICE HEALTH TOOLS =====\n'
root_source=$(findmnt -rno SOURCE / 2>/dev/null || true)
root_device=$(lsblk -no PKNAME "$root_source" 2>/dev/null || true)
[[ -n $root_device ]] && root_device=/dev/$root_device || root_device=$root_source
echo "root_device=$root_device"
if command -v smartctl >/dev/null 2>&1 && [[ -b $root_device ]]; then
    smartctl --health -- "$root_device" 2>&1 || true
else
    echo 'smartctl unavailable or root device is not a block device.'
fi
if command -v mmc >/dev/null 2>&1 && [[ $root_device == /dev/mmcblk* ]]; then
    media_type=$(cat "/sys/block/${root_device##*/}/device/type" 2>/dev/null || true)
    if [[ $media_type == MMC || $media_type == eMMC ]]; then
        echo "mmc_extcsd_device=$root_device"
        mmc extcsd read "$root_device" 2>&1 | grep -E 'DEVICE_LIFE_TIME|PRE_EOL_INFO|LIFE_TIME' || true
    else
        echo "mmc_extcsd=skipped (device type is ${media_type:-SD}; EXT_CSD is eMMC-only)"
    fi
else
    echo 'mmc-utils unavailable or root device is not MMC.'
fi

printf '\n===== STORAGE KERNEL MESSAGES =====\n'
root_block=${root_device##*/}
root_card=$(basename "$(readlink "/sys/class/block/$root_block/device" 2>/dev/null || true)" 2>/dev/null || true)
root_host=${root_card%%:*}
if [[ $root_block == mmcblk* ]]; then
    dmesg --color=never 2>/dev/null | grep -Ei "(${root_block}|${root_host}:|I/O error|buffer I/O|EXT[234]-fs error|read-only)" | tail -100 || \
        echo "No matching messages for root device $root_device found."
else
    dmesg --color=never 2>/dev/null | grep -Ei 'sd[a-z]|I/O error|buffer I/O|EXT[234]-fs error|read-only' | tail -100 || \
        echo 'No matching storage errors found or dmesg is unavailable.'
fi

printf '\n===== SUMMARY =====\n'
echo 'Read-only storage health report complete.'
echo "Evidence saved to $OUTPUT"
