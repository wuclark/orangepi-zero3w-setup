#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$REPO_ROOT/scripts"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

VENDOR_ROOT="$REPO_ROOT/vendor-root"
PVR_TARBALL="$REPO_ROOT/vendor-files/pvr-userspace.tar.gz"
VPU_TARBALL="$REPO_ROOT/vendor-files/vpu-userspace.tar.gz"
MODULE_PATH="$REPO_ROOT/vendor-files/pvrsrvkm.ko"
FIRMWARE_DIR=""
TARGET_USER=""
FORCE_VIDEO="HDMI-A-1:1920x1080@60D"
BUILD_IF_MISSING=yes
RUN_APT_UPDATE=no
ENABLE_X11VNC=yes
ALLOW_UNTESTED=no
INSTALL_VPU=auto
STAGING_ROOT=""
cleanup() { [[ -z $STAGING_ROOT ]] || rm -rf -- "$STAGING_ROOT"; }
trap cleanup EXIT

usage() {
    cat <<EOF
Zero3W PVR Forge — all-in-one Armbian installer

Usage:
  sudo ./install.sh [options]

Default input layout:
  vendor-files/pvr-userspace.tar.gz  Recommended GPU userspace input
  vendor-files/vpu-userspace.tar.gz  Optional VPU userspace input
  vendor-files/pvrsrvkm.ko    Matching module (built automatically if absent)

Options:
  --vendor-root DIR     Vendor filesystem root
  --pvr-tarball FILE    pvr-userspace.tar.gz (preferred)
  --vpu-tarball FILE    vpu-userspace.tar.gz (optional)
  --without-vpu         Do not install VPU userspace when its archive exists
  --module FILE         Existing matching pvrsrvkm.ko
  --firmware-dir DIR    Override firmware source directory
  --user USER           Desktop/autologin/VNC user (default: invoking user)
  --video MODE          Forced DRM mode (default: $FORCE_VIDEO)
  --no-force-video      Do not change Armbian's kernel command line
  --no-build            Do not build the module when --module is missing
  --update              Explicitly refresh apt metadata before package installs
  --without-x11vnc      Do not configure x11vnc
  --allow-untested      Permit a non-reference kernel with matching module
  -h, --help            Show this help

Example:
  cp /path/to/pvr-userspace.tar.gz vendor-files/
  cp /path/to/vpu-userspace.tar.gz vendor-files/  # optional
  sudo ./install.sh
EOF
}

while (($#)); do
    case "$1" in
        --vendor-root) VENDOR_ROOT="${2:?missing directory}"; shift 2 ;;
        --pvr-tarball) PVR_TARBALL="${2:?missing file}"; shift 2 ;;
        --vpu-tarball) VPU_TARBALL="${2:?missing file}"; shift 2 ;;
        --without-vpu) INSTALL_VPU=no; shift ;;
        --module) MODULE_PATH="${2:?missing file}"; shift 2 ;;
        --firmware-dir) FIRMWARE_DIR="${2:?missing directory}"; shift 2 ;;
        --user) TARGET_USER="${2:?missing user}"; shift 2 ;;
        --video) FORCE_VIDEO="${2:?missing mode}"; shift 2 ;;
        --no-force-video) FORCE_VIDEO=""; shift ;;
        --no-build) BUILD_IF_MISSING=no; shift ;;
        --update) RUN_APT_UPDATE=yes; shift ;;
        --without-x11vnc) ENABLE_X11VNC=no; shift ;;
        --allow-untested) ALLOW_UNTESTED=yes; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

require_root

TARGET_USER="$(resolve_real_user "$TARGET_USER")"
id "$TARGET_USER" >/dev/null 2>&1 || die "User does not exist: $TARGET_USER"

if [[ -f $PVR_TARBALL ]]; then
    STAGING_ROOT=$(mktemp -d -t zero3w-pvr-install.XXXXXXXX)
    PREPARE_ARGS=(--pvr-tarball "$PVR_TARBALL" --output "$STAGING_ROOT")
    [[ ! -f $VPU_TARBALL ]] || PREPARE_ARGS+=(--vpu-tarball "$VPU_TARBALL")
    "$SCRIPT_DIR/prepare-vendor-archives.sh" "${PREPARE_ARGS[@]}" >/dev/null
    VENDOR_ROOT=$STAGING_ROOT
elif [[ ! -d $VENDOR_ROOT ]]; then
    die "No PVR input found. Put pvr-userspace.tar.gz in vendor-files/, pass
--pvr-tarball FILE, or use the legacy --vendor-root DIR option. See
docs/vendor-sources.md. Proprietary files are not redistributed."
fi

if [[ ! -f "$MODULE_PATH" ]]; then
    [[ "$BUILD_IF_MISSING" == yes ]] || die "Module not found: $MODULE_PATH"

    log "No prebuilt module found; installing build prerequisites."
    export DEBIAN_FRONTEND=noninteractive
    [[ $RUN_APT_UPDATE == yes ]] && apt-get update
    apt-get install -y \
        git build-essential bc bison flex libssl-dev libelf-dev kmod

    if [[ ! -f "/lib/modules/$(uname -r)/build/Makefile" ]]; then
        HEADER_DEB="$(find /opt -maxdepth 1 -type f \
            -name 'linux-headers-current-sun60iw2_*_arm64.deb' \
            -print -quit 2>/dev/null || true)"
        if [[ -n "$HEADER_DEB" ]]; then
            log "Installing matching vendor kernel headers: $HEADER_DEB"
            dpkg -i "$HEADER_DEB" || apt-get install -f -y
        else
            die "Matching kernel headers are not installed.

Expected: /lib/modules/$(uname -r)/build/Makefile
The Orange Pi image commonly places its header package under /opt as:
  linux-headers-current-sun60iw2_*_arm64.deb

Install the headers for the running kernel and rerun this installer."
        fi
    fi

    install -d -m 755 "$(dirname "$MODULE_PATH")"
    "$SCRIPT_DIR/build-pvrsrvkm.sh" \
        --work-dir "$REPO_ROOT/build-pvrsrvkm" \
        --output "$MODULE_PATH"
fi

BOOTSTRAP_ARGS=(
    --vendor-root "$VENDOR_ROOT"
    --module "$MODULE_PATH"
    --user "$TARGET_USER"
)
[[ -n "$FIRMWARE_DIR" ]] && BOOTSTRAP_ARGS+=(--firmware-dir "$FIRMWARE_DIR")
[[ -n "$FORCE_VIDEO" ]] \
    && BOOTSTRAP_ARGS+=(--video "$FORCE_VIDEO") \
    || BOOTSTRAP_ARGS+=(--no-force-video)
[[ "$ALLOW_UNTESTED" == yes ]] && BOOTSTRAP_ARGS+=(--allow-untested)
[[ "$RUN_APT_UPDATE" == yes ]] && BOOTSTRAP_ARGS+=(--update)

"$SCRIPT_DIR/armbian-bootstrap.sh" "${BOOTSTRAP_ARGS[@]}"

if [[ $INSTALL_VPU != no && -f $VPU_TARBALL ]]; then
    "$SCRIPT_DIR/install-vpu-userspace.sh" --vendor-root "$VENDOR_ROOT/.zero3w-vpu"
fi

if [[ "$ENABLE_X11VNC" == yes ]]; then
    "$SCRIPT_DIR/install-x11vnc.sh" --user "$TARGET_USER"
fi

cat <<EOF

============================================================
 Zero3W PVR Forge installation completed
============================================================

User:        $TARGET_USER
GPU module:  $MODULE_PATH
Vendor root: $VENDOR_ROOT
PVR archive: $PVR_TARBALL
VPU archive: $([[ -f $VPU_TARBALL && $INSTALL_VPU != no ]] && echo installed || echo skipped)
x11vnc:      $ENABLE_X11VNC

Next steps:
  1. Reboot: sudo reboot
  2. Wait about 60 seconds for the safe delayed GPU load.
  3. Verify: $SCRIPT_DIR/verify.sh
EOF

if [[ "$ENABLE_X11VNC" == yes ]]; then
    cat <<EOF
  4. Connect your VNC viewer to this board on TCP port 5900.
EOF
fi
