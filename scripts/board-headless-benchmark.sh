#!/usr/bin/env bash
# Purpose: Run no-display GPU Vulkan, VPU decode, and NPU inference workloads.
# Platform: validated Orange Pi arm64 board with installed acceleration layers.
# Inputs: optional OUTPUT path; workload commands and test assets are board-local.
# Writes: timestamped benchmark evidence under /var/log by default.
# Safety: workloads are bounded and do not change configuration or reboot.
# Repeat behavior: safe to repeat; results vary with frequency, cooling, and load.
# Recovery: inspect the component evidence and rerun that component independently.
# Verification: all three sections must report PASS for a passing benchmark.
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
OUTPUT=${OUTPUT:-/var/log/orangepi-zero3w-setup/headless-benchmark-$(date -u +%Y%m%dT%H%M%SZ).txt}
[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo.' >&2; exit 1; }
install -d -m 755 "$(dirname "$OUTPUT")"
exec > >(tee "$OUTPUT") 2>&1

PASS=0; FAIL=0
run_benchmark() {
    local name=$1; shift; local result
    printf '\n===== %s =====\n' "$name"
    set +e
    "$@"
    result=$?
    set -e
    if ((result == 0)); then
        PASS=$((PASS + 1))
        printf 'RESULT: PASS - %s\n' "$name"
    else
        FAIL=$((FAIL + 1))
        printf 'RESULT: FAIL - %s\n' "$name"
    fi
}

echo "Headless Orange Pi acceleration benchmark: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
uname -a
run_benchmark 'GPU Vulkan compute' "$SCRIPT_DIR/run-vulkan-compute-benchmark.sh"
run_benchmark 'VPU H.264/H.265 decode' "$SCRIPT_DIR/test-vpu-decode.sh"
run_benchmark 'NPU inference' "$SCRIPT_DIR/test-npu.sh"
printf '\n===== SUMMARY =====\nPASS: %d  FAIL: %d\n' "$PASS" "$FAIL"
printf 'Evidence saved to %s\n' "$OUTPUT"
((FAIL == 0))
