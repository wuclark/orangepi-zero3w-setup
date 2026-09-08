#!/usr/bin/env bash
# Purpose: Run read-only validation for installed GPU, VPU, NPU, and display layers.
# Platform: Orange Pi board with the reference kernel; requires root.
# Inputs: optional --output and private NPU golden archives in vendor-files
#          (npu-golden-candidate.tar.gz and npu-golden-{lenet,yolov5,resnet50}.tar.gz).
# Writes: timestamped validation output and component evidence under /var/log.
# Safety: never installs, loads modules, changes configuration, or reboots.
# Repeat behavior: safe to repeat; unavailable optional layers are reported SKIP.
# Recovery: every SKIP names the exact prior step that provides the missing
#          piece; follow the printed remediation target for a failed component.
# Verification: PASS/FAIL/SKIP summary is the authoritative result of this check.
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
OUTPUT="/var/log/orangepi-zero3w-setup/board-validation-$(date -u +%Y%m%dT%H%M%SZ).txt"
NPU_GOLDEN_ARCHIVE=${NPU_GOLDEN_ARCHIVE:-/opt/orangepi-zero3w-setup/vendor-files/npu-golden-candidate.tar.gz}
while (($#)); do
    case "$1" in
        --output) OUTPUT=${2:?}; shift 2;;
        -h|--help) echo "Usage: sudo $0 [--output FILE]"; exit 0;;
        *) echo "ERROR: unknown option: $1" >&2; exit 2;;
    esac
done
[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo.' >&2; exit 1; }
install -d -m 755 "$(dirname "$OUTPUT")"
exec > >(tee "$OUTPUT") 2>&1

PASS=0; FAIL=0; SKIP=0; SUMMARY=()
run_check() {
    local label=$1; shift; local log
    log=$(mktemp -t zero3w-validation.XXXXXXXX)
    printf '\n===== %s =====\n' "$label"
    if "$@" >"$log" 2>&1; then
        cat "$log"; printf 'RESULT: PASS - %s\n' "$label"; PASS=$((PASS+1)); SUMMARY+=("PASS $label")
    else
        cat "$log"; printf 'RESULT: FAIL - %s\n' "$label"; FAIL=$((FAIL+1)); SUMMARY+=("FAIL $label")
    fi
    rm -f -- "$log"
}
skip_check() { printf 'RESULT: SKIP - %s\n' "$1"; SKIP=$((SKIP+1)); SUMMARY+=("SKIP $1"); }

echo "Orange Pi Zero 3W validation: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
uname -a
run_check 'GPU device/runtime checks' "$REPO_ROOT/tests/board/test-postboot-acceleration.sh" --gpu
run_check 'GPU Vulkan/EGL verification' "$REPO_ROOT/scripts/verify.sh"
if command -v g++ >/dev/null && command -v vulkaninfo >/dev/null && \
    { command -v glslc >/dev/null 2>&1 || command -v glslangValidator >/dev/null 2>&1; }; then
    run_check 'GPU Vulkan compute benchmark' "$REPO_ROOT/scripts/run-vulkan-compute-benchmark.sh" --output /var/log/orangepi-zero3w-setup/vulkan-compute-validation.txt
else
    skip_check 'GPU Vulkan compute benchmark (build tools unavailable; run: sudo make board-gpu-compute-deps)'
fi
run_check 'VPU device/runtime checks' "$REPO_ROOT/tests/board/test-postboot-acceleration.sh" --vpu
if [[ -e /etc/cedarc.conf ]]; then
    run_check 'VPU H.264/H.265 decode' "$REPO_ROOT/scripts/test-vpu-decode.sh" --output /var/log/orangepi-zero3w-setup/vpu-validation.txt
    if command -v ffmpeg >/dev/null && command -v gst-launch-1.0 >/dev/null; then
        run_check 'VPU Cedar vs software quality (PSNR/SSIM)' "$REPO_ROOT/scripts/test-vpu-quality.sh" --output /var/log/orangepi-zero3w-setup/vpu-quality-validation.txt
    else
        skip_check 'VPU Cedar vs software quality (ffmpeg or GStreamer is unavailable; run: sudo make board-vpu-install)'
    fi
else
    skip_check 'VPU H.264/H.265 decode (Cedar is not installed; run: sudo make board-vpu-install)'
fi
run_check 'NPU device/runtime checks' "$REPO_ROOT/tests/board/test-postboot-acceleration.sh" --npu
if [[ -x /opt/orangepi-zero3w-setup/npu-test/bin/vpm_run ]]; then
    run_check 'NPU VIPLite smoke test' "$REPO_ROOT/scripts/test-npu.sh" --output /var/log/orangepi-zero3w-setup/npu-validation.txt
else
    skip_check 'NPU VIPLite smoke test (runner is not installed; run: sudo make board-npu-install)'
fi
if [[ -f $NPU_GOLDEN_ARCHIVE ]]; then
    run_check 'NPU SDK golden candidate' "$REPO_ROOT/scripts/board-npu-golden-test.sh" \
        --archive "$NPU_GOLDEN_ARCHIVE" \
        --output /var/log/orangepi-zero3w-setup/npu-golden-validation.txt
else
    skip_check 'NPU SDK golden candidate (private archive is not installed; generate host-side: make npu-golden-candidate, then bake work/vendor-output/npu-golden-candidate.tar.gz into the image or copy it to /opt/orangepi-zero3w-setup/vendor-files/)'
fi
# ACUITY goldens produced host-side by scripts/generate-npu-golden.sh. Each
# check runs only when its archive and the full runner stack are present;
# anything missing is a SKIP naming the prior step, never a FAIL.
for NPU_GOLDEN_MODEL in lenet yolov5 resnet50; do
    NPU_MODEL_ARCHIVE=/opt/orangepi-zero3w-setup/vendor-files/npu-golden-$NPU_GOLDEN_MODEL.tar.gz
    if [[ ! -x /opt/orangepi-zero3w-setup/npu-test/bin/vpm_run ]]; then
        skip_check "NPU ACUITY golden ($NPU_GOLDEN_MODEL runner is not installed; run: sudo make board-npu-install)"
    elif ! command -v python3 >/dev/null; then
        skip_check "NPU ACUITY golden ($NPU_GOLDEN_MODEL python3 is not installed; rerun the board base setup)"
    elif [[ ! -f $NPU_MODEL_ARCHIVE ]]; then
        skip_check "NPU ACUITY golden ($NPU_GOLDEN_MODEL archive is not installed; generate host-side: NPU_ACUITY_IMAGE=ubuntu-npu:v2.0.10.2 make npu-golden-$NPU_GOLDEN_MODEL, then bake work/vendor-output/npu-golden-$NPU_GOLDEN_MODEL.tar.gz into the image or copy it to /opt/orangepi-zero3w-setup/vendor-files/)"
    else
        run_check "NPU ACUITY golden ($NPU_GOLDEN_MODEL)" "$REPO_ROOT/scripts/board-npu-model-test.sh" \
            --model "$NPU_GOLDEN_MODEL" \
            --output /var/log/orangepi-zero3w-setup/npu-golden-$NPU_GOLDEN_MODEL.txt
    fi
done
if [[ -S /tmp/.X11-unix/X0 ]]; then
    run_check 'X11 display :0' test -S /tmp/.X11-unix/X0
else
    skip_check 'X11 display :0 (not running)'
fi
if systemctl is-enabled --quiet x11vnc.service 2>/dev/null; then
    run_check 'x11vnc service' systemctl is-active --quiet x11vnc.service
else
    skip_check 'x11vnc service (not enabled)'
fi

printf '\n===== SUMMARY =====\n'
printf '%s\n' "${SUMMARY[@]}"
printf 'Totals: pass=%d fail=%d skip=%d\n' "$PASS" "$FAIL" "$SKIP"
printf 'Evidence saved to %s\n' "$OUTPUT"
if ! command -v glslc >/dev/null 2>&1 && ! command -v glslangValidator >/dev/null 2>&1; then
    printf 'ACTION: install the Vulkan compute tools, then rerun validation:\n'
    printf '  sudo make board-gpu-compute-deps\n'
fi
if ! systemctl is-enabled --quiet x11vnc.service 2>/dev/null; then
    printf 'OPTIONAL: install and enable x11vnc if remote X11 validation is desired:\n'
    printf '  sudo make remote-x11vnc\n'
fi
((FAIL == 0))
