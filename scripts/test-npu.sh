#!/usr/bin/env bash
set -Eeuo pipefail

TEST_ROOT=${1:-/opt/orangepi-zero3w-setup/npu-test}
[[ $EUID -eq 0 ]] || { echo 'ERROR: run the NPU test with sudo.' >&2; exit 1; }
runner="$TEST_ROOT/bin/vpm_run"
[[ -x $runner ]] || { echo "ERROR: NPU runner not found: $runner" >&2; exit 1; }
[[ -f $TEST_ROOT/vpm_run/sample.txt && -f $TEST_ROOT/vpm_run/network_binary.nb && \
   -f $TEST_ROOT/vpm_run/input_0.dat ]] || { echo 'ERROR: NPU test data is incomplete.' >&2; exit 1; }
log=$(mktemp -t zero3w-npu-run.XXXXXXXX)
trap 'rm -f -- "$log"' EXIT
(
    cd "$TEST_ROOT/vpm_run"
    LD_LIBRARY_PATH=/usr/local/lib/npu "$runner" -s sample.txt -l 3 -d 0 -b 1
) 2>&1 | tee "$log"
grep -Eiq 'vpm run ret[=: ]+0|run ret[=: ]+0' "$log" || {
    echo 'ERROR: NPU smoke test did not report success.' >&2; exit 1;
}
echo 'PASS: VIPLite NPU smoke test completed.'
