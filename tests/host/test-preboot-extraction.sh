#!/usr/bin/env bash
# Purpose: Verify preboot vendor extraction produces separated, checksummed component archives.
# Platform: Host-side temporary-fixture test; no board or proprietary archive is required.
# Inputs: Synthetic source tree created by the test itself.
# Dependencies: Bash, tar, sha256sum, and repository vendor extraction scripts.
# Writes: Temporary source/output trees and archives under /tmp; removes them on exit.
# Safety: Uses synthetic files and checks that kernel modules and components are not misplaced.
# Repeat: Safe to run repeatedly; each invocation creates a fresh temporary workspace.
# Outputs: Assertion failures or a preboot extraction tests passed message.
# Verification: Exit 0 confirms archive existence, manifests, checksums, and component placement.
# Documentation: docs/development/development.md
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TMP=$(mktemp -d -t zero3w-preboot-test.XXXXXXXX)
trap 'rm -rf -- "$TMP"' EXIT

mkdir -p "$TMP/source/etc" "$TMP/source/usr/lib" "$TMP/source/usr/local/lib/dri" \
  "$TMP/source/var/lib/dpkg/info" "$TMP/source/lib/modules/test"
touch "$TMP/source/usr/lib/libVK_IMG.so" \
  "$TMP/source/usr/local/lib/dri/pvr_dri.so" \
  "$TMP/source/usr/lib/libcedarc.so" \
  "$TMP/source/usr/lib/libVIPhal.so" \
  "$TMP/source/lib/modules/test/vipcore.ko"
printf '/usr/lib/libVK_IMG.so\n/usr/local/lib/dri/pvr_dri.so\n' \
  > "$TMP/source/var/lib/dpkg/info/xserver-xorg-img-bxm.list"
printf '/usr/lib/libcedarc.so\n' > "$TMP/source/var/lib/dpkg/info/libcedarc.list"

"$ROOT/scripts/extract-vendor-userspace.sh" \
  --source-root "$TMP/source" --output-dir "$TMP/output" >/dev/null

for component in pvr vpu npu; do
    archive="$TMP/output/${component}-userspace.tar.gz"
    [[ -s $archive && -s "$TMP/output/${component}-manifest.sha256" ]]
    (cd "$TMP/output" && sha256sum -c "${component}-manifest.sha256") >/dev/null
    ! tar -tzf "$archive" | grep -q 'lib/modules/'
done
tar -tzf "$TMP/output/pvr-userspace.tar.gz" | grep -q 'libVK_IMG.so'
tar -tzf "$TMP/output/vpu-userspace.tar.gz" | grep -q 'libcedarc.so'
tar -tzf "$TMP/output/npu-userspace.tar.gz" | grep -q 'libVIPhal.so'
printf 'preboot extraction tests passed\n'
