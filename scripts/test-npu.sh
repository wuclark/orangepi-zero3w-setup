#!/usr/bin/env bash
set -Eeuo pipefail

TEST_ROOT=/opt/orangepi-zero3w-setup/npu-test
OUTPUT=""
while (($#)); do
    case "$1" in
        --test-root) TEST_ROOT=${2:?}; shift 2;;
        --output) OUTPUT=${2:?}; shift 2;;
        -h|--help) echo "Usage: sudo $0 [--test-root DIR] [--output FILE]"; exit 0;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2;;
    esac
done
[[ $EUID -eq 0 ]] || { echo 'ERROR: run the NPU test with sudo.' >&2; exit 1; }
runner="$TEST_ROOT/bin/vpm_run"
[[ -x $runner ]] || { echo "ERROR: NPU runner not found: $runner" >&2; exit 1; }
[[ -f $TEST_ROOT/vpm_run/sample.txt && -f $TEST_ROOT/vpm_run/network_binary.nb && \
   -f $TEST_ROOT/vpm_run/input_0.dat ]] || { echo 'ERROR: NPU test data is incomplete.' >&2; exit 1; }
log=$(mktemp -t zero3w-npu-run.XXXXXXXX)
trap 'rm -f -- "$log"' EXIT
result=0
(
    cd "$TEST_ROOT/vpm_run"
    LD_LIBRARY_PATH=/usr/local/lib/npu "$runner" -s sample.txt -l 3 -d 0 -b 1
) 2>&1 | tee "$log" || result=${PIPESTATUS[0]}
if ! grep -Eiq 'vpm run ret[=: ]+0|run ret[=: ]+0' "$log"; then
    result=1
fi
if [[ -n $OUTPUT ]]; then
    install -d -m 755 "$(dirname "$OUTPUT")"
    {
        echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "kernel=$(uname -a)"
        echo "test_root=$TEST_ROOT"
        echo "device=$(stat -c '%t:%T %a %U:%G %n' /dev/vipcore 2>/dev/null || true)"
        echo "driver_module="
        modinfo vipcore 2>/dev/null | grep -E 'filename|version|vermagic|description' || true
        echo "modules="; lsmod | grep -Ei 'vip|nna|npu' || true
        echo "dmesg="; dmesg | grep -iE 'vip|npu|nna|galcore|vivante' | tail -100 || true
        echo "libraries="
        sha256sum /usr/local/lib/npu/libVIPhal.so /usr/local/lib/npu/libNBGlinker.so 2>/dev/null || true
        echo "model="; sha256sum "$TEST_ROOT/vpm_run/network_binary.nb" 2>/dev/null || true
        echo "input="; sha256sum "$TEST_ROOT/vpm_run/input_0.dat" 2>/dev/null || true
        echo "runner="; sha256sum "$runner" 2>/dev/null || true
        echo "output="
        cat "$log"
        echo "result=$result"
    } > "$OUTPUT"
    echo "Evidence saved to $OUTPUT"
fi
if ((result != 0)); then
    echo 'ERROR: NPU smoke test did not report success.' >&2
    exit 1
fi
echo 'PASS: VIPLite NPU smoke test completed.'
