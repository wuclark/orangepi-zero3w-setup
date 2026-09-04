#!/usr/bin/env bash
# Purpose: Safely extract selected NPU SDK files into a deterministic test-assets archive.
# Platform: Host-side preparation for the experimental Orange Pi NPU test flow.
# Inputs: Required --sdk-tarball and absent --output archive path.
# Dependencies: Bash, Python tarfile validation, tar, and scripts/lib.sh.
# Writes: A generated NPU test archive at the requested output; temporary extraction is removed on exit.
# Safety: Rejects traversal/absolute archive members and copies only an allowlisted SDK file set.
# Repeat: Refuses an existing output; use a new path after reviewing prior artifacts.
# Recovery: Remove only the generated output archive and temporary staging is automatically cleaned.
# Outputs: Deterministic npu-test archive containing the selected runner, model, inputs, and headers.
# Verification: Inspect the archive manifest and run the NPU test workflow on the target board.
# Documentation: docs/optional/npu.md
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
SDK_TARBALL=""; OUTPUT=""
while (($#)); do
    case "$1" in
        --sdk-tarball) SDK_TARBALL=${2:?}; shift 2;;
        --output) OUTPUT=${2:?}; shift 2;;
        -h|--help) echo "Usage: $0 --sdk-tarball FILE --output FILE"; exit 0;;
        *) die "Unknown argument: $1";;
    esac
done
[[ -f $SDK_TARBALL ]] || die "AI SDK archive not found: $SDK_TARBALL"
[[ -n $OUTPUT && ! -e $OUTPUT ]] || die "Output is missing or already exists: $OUTPUT"
work=$(mktemp -d -t zero3w-npu-assets.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
python3 - "$SDK_TARBALL" <<'PY'
import pathlib, sys, tarfile
with tarfile.open(sys.argv[1], "r:gz") as tf:
    for member in tf.getmembers():
        name = pathlib.PurePosixPath(member.name)
        if name.is_absolute() or ".." in name.parts:
            raise SystemExit(f"unsafe archive member: {member.name}")
PY
tar -xzf "$SDK_TARBALL" -C "$work"
sdk="$work/ai-sdk"; stage="$work/stage"
[[ -d $sdk ]] || die "AI SDK archive must contain ai-sdk/"
copy_required() {
    local source=$1 destination=$2
    [[ -f "$sdk/$source" ]] || die "AI SDK is missing: $source"
    install -d -m 755 "$(dirname "$stage/$destination")"
    cp -a "$sdk/$source" "$stage/$destination"
}
copy_required examples/vpm_run/vpm_run.c npu-test/vpm_run/vpm_run.c
copy_required examples/vpm_run/Makefile npu-test/vpm_run/Makefile
copy_required examples/vpm_run/makefile.linux npu-test/vpm_run/makefile.linux
copy_required examples/vpm_run/makefile.linux.def npu-test/vpm_run/makefile.linux.def
copy_required examples/vpm_run/operator/sample.txt npu-test/vpm_run/sample.txt
copy_required examples/vpm_run/operator/input_0.dat npu-test/vpm_run/input_0.dat
copy_required examples/vpm_run/operator/v3/network_binary.nb npu-test/vpm_run/network_binary.nb
copy_required examples/yolov5/model/v3/yolov5.nb npu-test/yolov5/yolov5.nb
copy_required examples/yolov5/input_data/dog_640_640.jpg npu-test/yolov5/dog_640_640.jpg
copy_required viplite-tina/lib/aarch64-none-linux-gnu/v2.0/inc/vip_lite.h npu-test/viplite/include/vip_lite.h
copy_required viplite-tina/lib/aarch64-none-linux-gnu/v2.0/inc/vip_lite_common.h npu-test/viplite/include/vip_lite_common.h
tar -C "$stage" --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 \
    --numeric-owner -czf "$OUTPUT" npu-test
printf 'Created NPU test asset archive: %s\n' "$OUTPUT"
