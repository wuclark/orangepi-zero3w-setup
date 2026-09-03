#!/usr/bin/env bash
# Purpose: Stage the AI SDK custom-LUT NPU golden candidate as a private bundle.
# Platform: Linux/WSL2 host; the SDK archive is a local, user-supplied input.
# Inputs: --sdk-tarball and --output; the output must not already exist.
# Writes: one generated archive under work/vendor-output or an explicit path.
# Safety: validates archive member paths and extracts only selected test files.
# Repeat behavior: refuses to overwrite; remove only a verified failed output.
# Provenance: files come from ai-sdk/examples/custom_lut/test in the SDK archive.
# Recovery: preserve the SDK archive and rerun with a new output path.
# Verification: run board-npu-golden-test; this is not the pinned operator sample.
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

work=$(mktemp -d -t zero3w-npu-golden.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
python3 - "$SDK_TARBALL" <<'PY'
import pathlib, sys, tarfile
with tarfile.open(sys.argv[1], "r:gz") as tf:
    for member in tf:
        name = pathlib.PurePosixPath(member.name)
        if name.is_absolute() or ".." in name.parts:
            raise SystemExit(f"unsafe archive member: {member.name}")
PY

sdk_prefix=ai-sdk/examples/custom_lut/test
tar --no-same-owner --no-same-permissions -xzf "$SDK_TARBALL" -C "$work" \
    "$sdk_prefix/sample.txt" "$sdk_prefix/input.txt" "$sdk_prefix/golden.bin" \
    "$sdk_prefix/models/v3/custom_lut.nb"
stage="$work/stage"
install -d -m 755 "$stage"
cp -a "$work/$sdk_prefix/input.txt" "$stage/input.txt"
cp -a "$work/$sdk_prefix/golden.bin" "$stage/golden.bin"
cp -a "$work/$sdk_prefix/models/v3/custom_lut.nb" "$stage/lut_test.nb"
cat > "$stage/sample.txt" <<'EOF'
[network]
./lut_test.nb
[input]
./input.txt
[golden]
./golden.bin
EOF
tar -C "$stage" --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 \
    --numeric-owner -czf "$OUTPUT" golden.bin input.txt lut_test.nb sample.txt
printf 'Created private NPU golden candidate: %s\n' "$OUTPUT"
