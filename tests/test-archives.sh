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
tar -C "$TMP/vpu" -czf "$TMP/vpu-userspace.tar.gz" .
out=$($ROOT/scripts/prepare-vendor-archives.sh \
  --pvr-tarball "$TMP/pvr-userspace.tar.gz" \
  --vpu-tarball "$TMP/vpu-userspace.tar.gz" --output "$TMP/out")
[[ $out == "$TMP/out" && -f $TMP/out/usr/lib/libVK_IMG.so ]]
[[ -f $TMP/out/.zero3w-vpu/usr/lib/aarch64-linux-gnu/libcedar_test.so ]]

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
