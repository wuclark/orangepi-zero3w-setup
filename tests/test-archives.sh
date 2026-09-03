#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d -t zero3w-archive-test.XXXXXXXX)
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/root/usr/lib" "$TMP/root/usr/local/lib/dri"
touch "$TMP/root/usr/lib/libVK_IMG.so" "$TMP/root/usr/lib/libsrv_um.so" \
  "$TMP/root/usr/lib/libGLESv2_PVR_MESA.so" \
  "$TMP/root/usr/local/lib/libpvr_mesa_wsi.so" \
  "$TMP/root/usr/local/lib/dri/pvr_dri.so"
tar -C "$TMP/root" -czf "$TMP/pvr-userspace.tar.gz" usr
mkdir -p "$TMP/vpu/usr/lib/aarch64-linux-gnu" "$TMP/vpu/etc/xdg"
touch "$TMP/vpu/usr/lib/aarch64-linux-gnu/libcedar_test.so"
printf 'hacks=test\n' > "$TMP/vpu/etc/xdg/gstomx.conf"
printf 'loglevel=4\n' > "$TMP/vpu/etc/cedarc.conf"
tar -C "$TMP/vpu" -czf "$TMP/vpu-userspace.tar.gz" .
mkdir -p "$TMP/npu/usr/local/lib/npu"
touch "$TMP/npu/usr/local/lib/npu/libVIPhal.so"
tar -C "$TMP/npu" -czf "$TMP/npu-userspace.tar.gz" .
out=$($ROOT/scripts/prepare-vendor-archives.sh \
  --pvr-tarball "$TMP/pvr-userspace.tar.gz" \
  --vpu-tarball "$TMP/vpu-userspace.tar.gz" \
  --npu-tarball "$TMP/npu-userspace.tar.gz" --output "$TMP/out")
[[ $out == "$TMP/out" && -f $TMP/out/usr/lib/libVK_IMG.so ]]
[[ -f $TMP/out/.zero3w-vpu/usr/lib/aarch64-linux-gnu/libcedar_test.so ]]
[[ -f $TMP/out/.zero3w-vpu/etc/cedarc.conf ]]
[[ -f $TMP/out/.zero3w-npu/usr/local/lib/npu/libVIPhal.so ]]

# The repository-owned extractor keeps GPU, VPU, and NPU archives isolated.
mkdir -p "$TMP/source/etc" "$TMP/source/usr/lib" "$TMP/source/usr/local/lib/dri" \
  "$TMP/source/var/lib/dpkg/info"
touch "$TMP/source/usr/lib/libVK_IMG.so" "$TMP/source/usr/local/lib/dri/pvr_dri.so" \
  "$TMP/source/usr/lib/libcedarc.so" "$TMP/source/usr/lib/libvipcore.so"
printf '/usr/lib/libVK_IMG.so\n/usr/local/lib/dri/pvr_dri.so\n' \
  > "$TMP/source/var/lib/dpkg/info/xserver-xorg-img-bxm.list"
printf '/usr/lib/libcedarc.so\n' > "$TMP/source/var/lib/dpkg/info/libcedarc.list"
printf 'loglevel=4\n' > "$TMP/source/etc/cedarc.conf"
"$ROOT/scripts/extract-vendor-userspace.sh" \
  --source-root "$TMP/source" --output-dir "$TMP/generated" >/dev/null
tar -tzf "$TMP/generated/pvr-userspace.tar.gz" | grep -q 'usr/lib/libVK_IMG.so'
tar -tzf "$TMP/generated/vpu-userspace.tar.gz" | grep -q 'usr/lib/libcedarc.so'
tar -tzf "$TMP/generated/vpu-userspace.tar.gz" | grep -q 'etc/cedarc.conf'
tar -tzf "$TMP/generated/npu-userspace.tar.gz" | grep -q 'usr/lib/libvipcore.so'
! tar -tzf "$TMP/generated/npu-userspace.tar.gz" | grep -q 'libVK_IMG.so'

# The SDK golden-candidate staging keeps only the complete custom-LUT test set.
mkdir -p "$TMP/sdk/ai-sdk/examples/custom_lut/test/models/v3"
printf '[network]\n./lut_test.nb\n[input]\n./input.txt\n[golden]\n./golden.bin\n' \
  > "$TMP/sdk/ai-sdk/examples/custom_lut/test/sample.txt"
printf '0\n1\n2\n' > "$TMP/sdk/ai-sdk/examples/custom_lut/test/input.txt"
printf 'golden' > "$TMP/sdk/ai-sdk/examples/custom_lut/test/golden.bin"
printf 'nbg' > "$TMP/sdk/ai-sdk/examples/custom_lut/test/models/v3/custom_lut.nb"
tar -C "$TMP/sdk" -czf "$TMP/ai-sdk.tar.gz" ai-sdk
"$ROOT/scripts/stage-npu-golden-candidate.sh" \
  --sdk-tarball "$TMP/ai-sdk.tar.gz" --output "$TMP/npu-golden-candidate.tar.gz" >/dev/null
tar -tzf "$TMP/npu-golden-candidate.tar.gz" | sort | diff -u - <(printf '%s\n' \
  golden.bin input.txt lut_test.nb sample.txt)

# A traversal member must be rejected before extraction.
python3 - "$TMP/unsafe.tar.gz" <<'PY'
import io, sys, tarfile
with tarfile.open(sys.argv[1], "w:gz") as tf:
    info = tarfile.TarInfo("../escape")
    data = b"no"
    info.size = len(data)
    tf.addfile(info, io.BytesIO(data))
PY
if "$ROOT/scripts/prepare-vendor-archives.sh" \
    --pvr-tarball "$TMP/unsafe.tar.gz" --output "$TMP/unsafe-out" >/dev/null 2>&1; then
    echo 'unsafe archive was accepted' >&2
    exit 1
fi
printf 'archive tests passed\n'
