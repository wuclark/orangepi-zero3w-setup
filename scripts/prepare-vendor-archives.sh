#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

PVR_TARBALL=""
VPU_TARBALL=""
NPU_TARBALL=""
OUTPUT=""

usage() {
    cat <<'EOF'
Usage: prepare-vendor-archives.sh --pvr-tarball FILE [options]

Safely validates and extracts userspace archives produced by
OrangePiZero3W-GPU-VPU into a temporary vendor root. It never extracts over /.

Options:
  --pvr-tarball FILE  Required pvr-userspace.tar.gz
  --vpu-tarball FILE  Optional vpu-userspace.tar.gz
  --npu-tarball FILE  Optional npu-userspace.tar.gz (validation only)
  --output DIR        Extraction directory (must not already exist)
EOF
}

while (($#)); do
    case "$1" in
        --pvr-tarball) PVR_TARBALL=${2:?}; shift 2 ;;
        --vpu-tarball) VPU_TARBALL=${2:?}; shift 2 ;;
        --npu-tarball) NPU_TARBALL=${2:?}; shift 2 ;;
        --output) OUTPUT=${2:?}; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

[[ -f $PVR_TARBALL ]] || die "PVR archive not found: $PVR_TARBALL"
[[ -z $VPU_TARBALL || -f $VPU_TARBALL ]] || die "VPU archive not found: $VPU_TARBALL"
[[ -z $NPU_TARBALL || -f $NPU_TARBALL ]] || die "NPU archive not found: $NPU_TARBALL"
OUTPUT=${OUTPUT:-$(mktemp -d -t zero3w-pvr-vendor.XXXXXXXX)}
[[ ! -e $OUTPUT ]] || { [[ -d $OUTPUT && -z $(find "$OUTPUT" -mindepth 1 -print -quit) ]] || die "Output must be absent or empty: $OUTPUT"; }
install -d -m 700 "$OUTPUT"

validate_archive() {
    local archive=$1
    python3 - "$archive" <<'PY' || die "Unsafe or unreadable archive: $archive"
import pathlib, sys, tarfile
p = pathlib.PurePosixPath
with tarfile.open(sys.argv[1], "r:gz") as tf:
    for m in tf.getmembers():
        name = p(m.name)
        if name.is_absolute() or ".." in name.parts:
            raise SystemExit(f"unsafe member path: {m.name}")
        if m.issym() or m.islnk():
            target = p(m.linkname)
            if target.is_absolute() or ".." in target.parts:
                raise SystemExit(f"unsafe link target: {m.name} -> {m.linkname}")
PY
}

extract_archive() {
    local archive=$1 destination=$2
    validate_archive "$archive"
    install -d -m 700 "$destination"
    tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$destination"
}

extract_archive "$PVR_TARBALL" "$OUTPUT"
[[ -z $VPU_TARBALL ]] || extract_archive "$VPU_TARBALL" "$OUTPUT/.zero3w-vpu"
[[ -z $NPU_TARBALL ]] || extract_archive "$NPU_TARBALL" "$OUTPUT/.zero3w-npu"

# Accept archives rooted at usr/ or ./usr/. Reject unexpected wrapper folders.
[[ -d $OUTPUT/usr ]] || die "Archive does not contain usr/ at its root."
required=(
  'usr/lib/libVK_IMG.so*'
  'usr/lib/libsrv_um.so*'
  'usr/lib/libGLESv2_PVR_MESA.so*'
  'usr/local/lib/libpvr_mesa_wsi.so*'
  'usr/local/lib/dri/pvr_dri.so'
)
for pattern in "${required[@]}"; do
    compgen -G "$OUTPUT/$pattern" >/dev/null || die "PVR archive is missing: $pattern"
done

if [[ -n $NPU_TARBALL ]]; then
    npu_found=no
    for pattern in "$OUTPUT/.zero3w-npu/usr/local/lib/npu/libVIPhal.so*" \
        "$OUTPUT/.zero3w-npu/usr/lib/libVIPhal.so*" \
        "$OUTPUT/.zero3w-npu/usr/lib/aarch64-linux-gnu/libVIPhal.so*"; do
        compgen -G "$pattern" >/dev/null && npu_found=yes
    done
    [[ $npu_found == yes ]] || die "NPU archive is missing libVIPhal.so"
    ! find "$OUTPUT/.zero3w-npu" -path '*/lib/modules/*' -print -quit | grep -q . || \
        die "NPU archive must not contain kernel modules"
fi

printf '%s\n' "$OUTPUT"
