#!/usr/bin/env bash
# Purpose: Run the AI SDK custom-LUT NPU test with its supplied binary golden.
# Platform: arm64 Orange Pi with /dev/vipcore, installed NPU runtime, and vpm_run.
# Inputs: --archive and optional --output; archive is a private host handoff.
# Requires: root, tar, Python 3, /usr/local/lib/npu, and the installed vpm_run.
# Writes: temporary extraction data and a root-owned evidence log; no config edits.
# Safety: validates paths, never installs files, and does not call the NPU installer.
# Repeat behavior: safe to repeat; each run replaces only its explicit output log.
# Limitation: custom-LUT candidate only; it does not validate operator/v3/network_binary.nb.
# Verification: PASS requires vpm_run to report "Test output 0 passed.".
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root
ARCHIVE=${NPU_GOLDEN_ARCHIVE:-/opt/orangepi-zero3w-setup/vendor-files/npu-golden-candidate.tar.gz}
OUTPUT=${NPU_GOLDEN_OUTPUT:-/var/log/orangepi-zero3w-setup/npu-golden-candidate.txt}
while (($#)); do
    case "$1" in
        --archive) ARCHIVE=${2:?}; shift 2;;
        --output) OUTPUT=${2:?}; shift 2;;
        -h|--help) echo "Usage: sudo $0 [--archive FILE] [--output FILE]"; exit 0;;
        *) die "Unknown argument: $1";;
    esac
done
[[ -f $ARCHIVE ]] || die "NPU golden candidate archive not found: $ARCHIVE"
RUNNER=/opt/orangepi-zero3w-setup/npu-test/bin/vpm_run
[[ -x $RUNNER ]] || die "Installed vpm_run not found: $RUNNER"

work=$(mktemp -d -t zero3w-npu-golden-run.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
python3 - "$ARCHIVE" <<'PY'
import pathlib, sys, tarfile
with tarfile.open(sys.argv[1], "r:gz") as tf:
    required = {"golden.bin", "input.txt", "lut_test.nb", "sample.txt"}
    names = set()
    for member in tf.getmembers():
        name = pathlib.PurePosixPath(member.name)
        if name.is_absolute() or ".." in name.parts or not member.isfile():
            raise SystemExit(f"unsafe candidate archive member: {member.name}")
        names.add(member.name.lstrip("./"))
    missing = required - names
    if missing:
        raise SystemExit(f"candidate archive missing: {', '.join(sorted(missing))}")
PY
tar --no-same-owner --no-same-permissions -xzf "$ARCHIVE" -C "$work"
log=$(mktemp -t zero3w-npu-golden-output.XXXXXXXX)
trap 'rm -rf -- "$work"; rm -f -- "$log"' EXIT
result=0
(
    cd "$work"
    LD_LIBRARY_PATH=/usr/local/lib/npu "$RUNNER" -s sample.txt -l 1 -d 0 -b 0 --save_txt 1
) 2>&1 | tee "$log" || result=${PIPESTATUS[0]}
if ! grep -Fq 'Test output 0 passed.' "$log"; then
    result=1
fi
install -d -m 755 "$(dirname "$OUTPUT")"
{
    echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "kernel=$(uname -a)"
    echo "archive=$ARCHIVE"
    echo "golden_sha256=$(sha256sum "$work/golden.bin" | awk '{print $1}')"
    echo "nbg_sha256=$(sha256sum "$work/lut_test.nb" | awk '{print $1}')"
    echo "input_sha256=$(sha256sum "$work/input.txt" | awk '{print $1}')"
    echo "result=$result"
    echo "output="
    cat "$log"
} > "$OUTPUT"
echo "Evidence saved to $OUTPUT"
if ((result != 0)); then
    echo 'ERROR: NPU golden candidate did not pass.' >&2
    exit 1
fi
echo 'PASS: NPU golden candidate matched.'
