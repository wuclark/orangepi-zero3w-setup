#!/usr/bin/env bash
# Purpose: Install staged VIPLite NPU userspace and its smoke-test assets.
# Board assumptions: arm64 Orange Pi Zero 3W with a matching /dev/vipcore driver.
# Inputs: --vendor-root and --test-archive; both must come from private staging.
# Writes: /usr/local/lib/npu, /opt/orangepi-zero3w-setup/npu-test, and backups.
# Safety: validates archive paths and never installs the kernel module from userspace.
# Repeat behavior: replaces the staged runtime while retaining timestamped backups.
# Recovery: restore the newest NPU backup, then rerun board-npu-verify.
# Verification: board-npu-test and board-validation must complete successfully.
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
VENDOR_ROOT=""; TEST_ARCHIVE=""
while (($#)); do
    case "$1" in
        --vendor-root) VENDOR_ROOT=${2:?}; shift 2;;
        --test-archive) TEST_ARCHIVE=${2:?}; shift 2;;
        -h|--help) echo "Usage: sudo $0 --vendor-root ROOT --test-archive FILE"; exit 0;;
        *) die "Unknown argument: $1";;
    esac
done
[[ -d $VENDOR_ROOT ]] || die "NPU vendor root not found: $VENDOR_ROOT"
[[ -f $TEST_ARCHIVE ]] || die "NPU test archive not found: $TEST_ARCHIVE"
[[ -f $VENDOR_ROOT/usr/local/lib/npu/libVIPhal.so ]] || die "NPU HAL is missing"
[[ -f $VENDOR_ROOT/usr/local/lib/npu/libNBGlinker.so ]] || die "NPU linker is missing"

BACKUP_ROOT="/var/backups/$PROJECT_NAME/npu-$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 700 "$BACKUP_ROOT"
for file in /usr/local/lib/npu/libVIPhal.so /usr/local/lib/npu/libNBGlinker.so; do
    [[ ! -e $file ]] || cp -a -- "$file" "$BACKUP_ROOT/"
done
install -d -m 755 /usr/local/lib/npu
cp -a "$VENDOR_ROOT/usr/local/lib/npu/"*.so /usr/local/lib/npu/

stage=$(mktemp -d -t zero3w-npu-test.XXXXXXXX)
trap 'rm -rf -- "$stage"' EXIT
python3 - "$TEST_ARCHIVE" <<'PY'
import pathlib, sys, tarfile
with tarfile.open(sys.argv[1], "r:gz") as tf:
    for member in tf.getmembers():
        name = pathlib.PurePosixPath(member.name)
        if name.is_absolute() or ".." in name.parts:
            raise SystemExit(f"unsafe archive member: {member.name}")
PY
tar --no-same-owner --no-same-permissions -xzf "$TEST_ARCHIVE" -C "$stage"
[[ -d $stage/npu-test ]] || die "NPU test archive is missing npu-test/"
TEST_ROOT=/opt/orangepi-zero3w-setup/npu-test
install -d -m 755 "$TEST_ROOT"
cp -a "$stage/npu-test/." "$TEST_ROOT/"
install -d -m 755 "$TEST_ROOT/bin"
gcc -O2 -DNPU_SW_VERSION=2 \
    -I"$TEST_ROOT/viplite/include" \
    "$TEST_ROOT/vpm_run/vpm_run.c" \
    -L/usr/local/lib/npu -Wl,-rpath,/usr/local/lib/npu \
    -lNBGlinker -lVIPhal -lm -o "$TEST_ROOT/bin/vpm_run"
chmod 755 "$TEST_ROOT/bin/vpm_run"
cat > /etc/ld.so.conf.d/orangepi-zero3w-npu.conf <<'EOF'
/usr/local/lib/npu
EOF
ldconfig
log "Installed NPU runtime and compiled test runner under $TEST_ROOT; backup: $BACKUP_ROOT"
