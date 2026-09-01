#!/usr/bin/env bash
set -Eeuo pipefail

pass=0
warn=0
GPU=no; VPU=no; NPU=no; OUTPUT=""
while (($#)); do
    case "$1" in
        --gpu) GPU=yes; shift;;
        --vpu) VPU=yes; shift;;
        --npu) NPU=yes; shift;;
        --all) GPU=yes; VPU=yes; NPU=yes; shift;;
        --output) OUTPUT=${2:?}; shift 2;;
        -h|--help) echo "Usage: $0 [--gpu|--vpu|--npu|--all] [--output FILE]"; exit 0;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2;;
    esac
done
if [[ $GPU == no && $VPU == no && $NPU == no ]]; then GPU=yes; VPU=yes; NPU=yes; fi
check() {
    local label=$1; shift
    if "$@"; then
        printf 'PASS: %s\n' "$label"; pass=$((pass + 1))
    else
        printf 'WARN: %s\n' "$label"; warn=$((warn + 1))
    fi
}

printf 'Orange Pi Zero 3W post-boot acceleration checks\n'
printf 'Kernel: '; uname -r
check 'arm64 userspace' test "$(dpkg --print-architecture 2>/dev/null || true)" = arm64
check 'expected kernel release' sh -c 'uname -r | grep -q "6.6.98.*sun60iw2"'
if [[ $GPU == yes ]]; then
    check 'GPU module loaded' sh -c 'lsmod | grep -q "^pvrsrvkm\b"'
    check 'HDMI DRM node' test -e /dev/dri/card0
    check 'PowerVR render node' test -e /dev/dri/renderD128
    check 'PowerVR firmware' sh -c 'test -e /lib/firmware/rgx.fw.36.56.104.183 || test -e /usr/lib/firmware/rgx.fw.36.56.104.183'
    check 'Vulkan summary available' command -v vulkaninfo
fi
if [[ $VPU == yes ]]; then
    check 'GStreamer available' command -v gst-launch-1.0
    check 'Cedar device node' sh -c 'find /dev -maxdepth 1 -name "cedar_dev*" -print -quit | grep -q .'
fi
if [[ $NPU == yes ]]; then
    check 'NPU device node' test -e /dev/vipcore
    check 'VIPLite HAL present' sh -c 'find /usr /opt /home -name libVIPhal.so -print -quit 2>/dev/null | grep -q .'
    check 'VIPLite linker present' sh -c 'find /usr /opt /home -name libNBGlinker.so -print -quit 2>/dev/null | grep -q .'
fi

printf 'Checks passed: %d; warnings: %d\n' "$pass" "$warn"
if [[ -n $OUTPUT ]]; then
    mkdir -p "$(dirname "$OUTPUT")"
    {
        echo "uname=$(uname -a)"
        echo "kernel=$(uname -r)"
        echo "architecture=$(dpkg --print-architecture 2>/dev/null || true)"
        echo "devices="; ls -l /dev/dri /dev/vipcore 2>/dev/null || true
        echo "modules="; lsmod | grep -E 'pvrsrvkm|sunxi_npu' || true
        echo "firmware="; find /lib/firmware /usr/lib/firmware -maxdepth 1 -name 'rgx.*' -type f -exec sha256sum {} \; 2>/dev/null || true
        echo "vulkan="; vulkaninfo --summary 2>&1 || true
    } > "$OUTPUT"
    printf 'Evidence saved to %s\n' "$OUTPUT"
fi
printf 'This is diagnostic only; it does not install, load, or reboot anything.\n'
[[ $warn -eq 0 ]]
