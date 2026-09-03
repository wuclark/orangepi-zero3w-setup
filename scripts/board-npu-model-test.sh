#!/usr/bin/env bash
# Purpose: Run a named NPU golden (lenet/yolov5/resnet50) on real board
#          hardware and semantically compare its output against the ACUITY
#          host golden tensor packaged alongside it.
# Platform: arm64 Orange Pi with /dev/vipcore, installed NPU runtime, and
#          the installed vpm_run test binary.
# Inputs: --model {lenet,yolov5,resnet50}, --archive (private host handoff,
#          from scripts/generate-npu-golden.sh), optional --output.
# Requires: root, tar, Python 3, /usr/local/lib/npu, and installed vpm_run.
# Writes: temporary extraction data and a root-owned evidence log; no config
#          edits, no package installs.
# Safety: validates archive member paths; never installs files or touches
#          the NPU installer/config.
# Repeat behavior: safe to repeat; each run replaces only its explicit
#          output log.
# Why not vpm_run's built-in [golden] check: that check is a raw memcmp()
#          (see ai-sdk/examples/vpm_run/vpm_run.c). These goldens come from
#          a separate ACUITY host quantization run, not the exact run that
#          produced the NBG under test, so a byte-exact match isn't a
#          meaningful pass/fail bar here. Instead this script runs vpm_run
#          with --save_txt 1 (no [golden] section in sample.txt) and
#          compares the saved output_N.txt against the packaged
#          host_output_N.txt with scripts/compare-npu-output.py (top-K
#          index match, max/mean abs diff, RMSE, cosine).
# Verification: PASS requires vpm_run to report success AND
#          compare-npu-output.py to report "result: pass" for every output.
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

MODEL=""
ARCHIVE=""
OUTPUT=""
TOP_K=5
MAX_ABS_DIFF=""
MIN_COSINE=""

usage() {
    cat <<'EOF'
Usage: sudo scripts/board-npu-model-test.sh --model {lenet,yolov5,resnet50} \
    [--archive FILE] [--output FILE] [--top-k N]
    [--max-abs-diff N] [--min-cosine N]

  --archive defaults to
    /opt/orangepi-zero3w-setup/vendor-files/npu-golden-<model>.tar.gz
  --output defaults to
    /var/log/orangepi-zero3w-setup/npu-golden-<model>.txt
  --max-abs-diff / --min-cosine are optional stricter thresholds; without
    them, PASS only requires vpm_run success plus a reported comparison
    (read the printed metrics yourself for borderline cases).
EOF
}

while (($#)); do
    case "$1" in
        --model) MODEL=${2:?}; shift 2;;
        --archive) ARCHIVE=${2:?}; shift 2;;
        --output) OUTPUT=${2:?}; shift 2;;
        --top-k) TOP_K=${2:?}; shift 2;;
        --max-abs-diff) MAX_ABS_DIFF=${2:?}; shift 2;;
        --min-cosine) MIN_COSINE=${2:?}; shift 2;;
        -h|--help) usage; exit 0;;
        *) die "Unknown argument: $1";;
    esac
done

case "$MODEL" in
    lenet|yolov5|resnet50) ;;
    "") die "Missing --model {lenet,yolov5,resnet50}";;
    *) die "Unknown --model: $MODEL (expected lenet, yolov5, or resnet50)";;
esac
ARCHIVE=${ARCHIVE:-/opt/orangepi-zero3w-setup/vendor-files/npu-golden-$MODEL.tar.gz}
OUTPUT=${OUTPUT:-/var/log/orangepi-zero3w-setup/npu-golden-$MODEL.txt}
[[ -f $ARCHIVE ]] || die "NPU golden archive not found: $ARCHIVE"
RUNNER=/opt/orangepi-zero3w-setup/npu-test/bin/vpm_run
[[ -x $RUNNER ]] || die "Installed vpm_run not found: $RUNNER"
require_command python3

work=$(mktemp -d -t zero3w-npu-model-test.XXXXXXXX)
log=$(mktemp -t zero3w-npu-model-output.XXXXXXXX)
trap 'rm -rf -- "$work"; rm -f -- "$log"' EXIT

python3 - "$ARCHIVE" <<'PY'
import pathlib, sys, tarfile
with tarfile.open(sys.argv[1], "r:gz") as tf:
    required = {"sample.txt", "network_binary.nb"}
    names = set()
    for member in tf.getmembers():
        name = pathlib.PurePosixPath(member.name)
        if name.is_absolute() or ".." in name.parts or not (member.isfile() or member.isdir()):
            raise SystemExit(f"unsafe archive member: {member.name}")
        if member.isfile():
            names.add(member.name.lstrip("./"))
    missing = required - names
    if missing:
        raise SystemExit(f"golden archive missing: {', '.join(sorted(missing))}")
PY
tar --no-same-owner --no-same-permissions -xzf "$ARCHIVE" -C "$work"

result=0
(
    cd "$work"
    LD_LIBRARY_PATH=/usr/local/lib/npu "$RUNNER" -s sample.txt -l 1 -d 0 -b 0 --save_txt 1
) 2>&1 | tee "$log" || result=${PIPESTATUS[0]}
if ! grep -Eiq 'vpm run ret[=: ]+0|run ret[=: ]+0' "$log"; then
    result=1
fi

compare_summary=""
compare_status=0
if ((result == 0)); then
    shopt -s nullglob
    golden_files=("$work"/host_output_*.txt)
    shopt -u nullglob
    if ((${#golden_files[@]} == 0)); then
        compare_summary="ERROR: no host_output_N.txt found in archive; cannot semantically verify"
        compare_status=1
    fi
    for golden_file in "${golden_files[@]}"; do
        index=$(sed -E 's/.*host_output_([0-9]+)\.txt/\1/' <<<"$golden_file")
        board_file="$work/output_$index.txt"
        if [[ ! -f $board_file ]]; then
            compare_summary+=$'\n'"ERROR: board did not produce output_$index.txt"
            compare_status=1
            continue
        fi
        one_summary=$(python3 "$SCRIPT_DIR/compare-npu-output.py" "$golden_file" "$board_file" \
            --top-k "$TOP_K" \
            ${MAX_ABS_DIFF:+--max-abs-diff "$MAX_ABS_DIFF"} \
            ${MIN_COSINE:+--min-cosine "$MIN_COSINE"} \
            --require-top-match) || compare_status=1
        compare_summary+=$'\n'"--- output_$index ---"$'\n'"$one_summary"
    done
else
    compare_summary="SKIPPED: vpm_run did not report success"
    compare_status=1
fi

install -d -m 755 "$(dirname "$OUTPUT")"
{
    echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "kernel=$(uname -a)"
    echo "model=$MODEL"
    echo "archive=$ARCHIVE"
    echo "nbg_sha256=$(sha256sum "$work/network_binary.nb" | awk '{print $1}')"
    echo "vpm_run_result=$result"
    echo "compare_result=$compare_status"
    echo "vpm_run_output="
    cat "$log"
    echo "comparison="
    echo "$compare_summary"
} > "$OUTPUT"
echo "Evidence saved to $OUTPUT"

if ((result != 0 || compare_status != 0)); then
    echo "ERROR: NPU golden test for $MODEL did not pass." >&2
    exit 1
fi
echo "PASS: NPU golden test for $MODEL matched (top-$TOP_K, see $OUTPUT for metrics)."
