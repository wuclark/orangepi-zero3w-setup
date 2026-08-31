#!/usr/bin/env bash
set -Eeuo pipefail

# Optional Orange Pi Zero 3W GPU — documented fresh-Armbian entry point
#
# Run this script ON THE ORANGE PI after the Windows transfer script has copied
# the extracted PowerVR filesystem into this repository's vendor-root folder.
#
# What this script does:
#   1. Confirms that the vendor files transferred successfully.
#   2. Confirms that sudo and network access are available.
#   3. Calls install.sh, which builds/validates pvrsrvkm.ko as necessary.
#   4. Installs Vulkan, X11, LightDM, Openbox, DRI3 and x11vnc.
#   5. Records the complete terminal output in gpu-bringup-logs/.
#   6. Leaves reboot under your control unless --reboot is supplied.
#
# Normal use:
#   chmod +x armbian-startup.sh
#   ./armbian-startup.sh
#
# The proprietary DDK is deliberately not downloaded by this project. Use the
# included Windows/Copy-VendorArchives.ps1 script to supply it. The older
# Copy-PvrVendorRoot.ps1 remains available only for extracted-tree debugging.

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_ROOT="$REPO_ROOT/vendor-root"
PVR_TARBALL="$REPO_ROOT/vendor-files/pvr-userspace.tar.gz"
VPU_TARBALL="$REPO_ROOT/vendor-files/vpu-userspace.tar.gz"
MODULE_PATH="$REPO_ROOT/vendor-files/pvrsrvkm.ko"
TARGET_USER="${SUDO_USER:-${USER:-orangepi}}"
DO_REBOOT=no
INSTALL_X11VNC=yes
INSTALL_VPU=auto
RUN_APT_UPDATE=no

usage() {
    cat <<EOF
Usage: ./armbian-startup.sh [options]

Options:
  --vendor-root DIR    Transferred vendor filesystem (default: vendor-root/)
  --pvr-tarball FILE   Transferred pvr-userspace.tar.gz (preferred)
  --vpu-tarball FILE   Optional vpu-userspace.tar.gz
  --without-vpu        Skip optional VPU userspace
  --module FILE        Existing pvrsrvkm.ko; built if missing
  --user USER          Desktop and VNC user (default: $TARGET_USER)
  --without-x11vnc     Install the graphics desktop without VNC
  --update             Explicitly refresh apt metadata before package installs
  --reboot             Reboot automatically after a successful installation
  -h, --help           Show this help
EOF
}

while (($#)); do
    case "$1" in
        --vendor-root) VENDOR_ROOT="${2:?missing directory}"; shift 2 ;;
        --pvr-tarball) PVR_TARBALL="${2:?missing file}"; shift 2 ;;
        --vpu-tarball) VPU_TARBALL="${2:?missing file}"; shift 2 ;;
        --without-vpu) INSTALL_VPU=no; shift ;;
        --module) MODULE_PATH="${2:?missing file}"; shift 2 ;;
        --user) TARGET_USER="${2:?missing user}"; shift 2 ;;
        --without-x11vnc) INSTALL_X11VNC=no; shift ;;
        --update) RUN_APT_UPDATE=yes; shift ;;
        --reboot) DO_REBOOT=yes; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

command -v sudo >/dev/null 2>&1 || {
    echo "ERROR: sudo is required." >&2
    exit 1
}
command -v apt-get >/dev/null 2>&1 || {
    echo "ERROR: This script expects an Armbian Debian/Ubuntu system." >&2
    exit 1
}
[[ "$(uname -m)" == aarch64 ]] || {
    echo "ERROR: Run this on the arm64 Orange Pi, not the Windows computer." >&2
    exit 1
}
[[ -f "$PVR_TARBALL" || -d "$VENDOR_ROOT" ]] || {
    cat >&2 <<EOF
ERROR: Vendor filesystem not found: $VENDOR_ROOT

From Windows PowerShell, run:
  .\windows\Copy-VendorArchives.ps1 -SourceDirectory C:\path\to\archives \
    -BoardHost YOUR_ORANGE_PI_IP
EOF
    exit 1
}

mkdir -p "$REPO_ROOT/gpu-bringup-logs"
LOG_FILE="$REPO_ROOT/gpu-bringup-logs/install-$(date -u +%Y%m%dT%H%M%SZ).log"

INSTALL_ARGS=(
    --module "$MODULE_PATH"
    --user "$TARGET_USER"
)
if [[ -f $PVR_TARBALL ]]; then
    INSTALL_ARGS+=(--pvr-tarball "$PVR_TARBALL")
    [[ ! -f $VPU_TARBALL ]] || INSTALL_ARGS+=(--vpu-tarball "$VPU_TARBALL")
else
    INSTALL_ARGS+=(--vendor-root "$VENDOR_ROOT")
fi
[[ "$INSTALL_X11VNC" == no ]] && INSTALL_ARGS+=(--without-x11vnc)
[[ ${INSTALL_VPU:-auto} == no ]] && INSTALL_ARGS+=(--without-vpu)
[[ ${RUN_APT_UPDATE:-no} == yes ]] && INSTALL_ARGS+=(--update)

echo "Installation log: $LOG_FILE"
echo "You may be prompted for your sudo password and then for a VNC password."

# PIPESTATUS preserves install.sh's result instead of accidentally returning
# tee's result. The error trap is intentionally avoided so the log remains easy
# to read and a failed install never triggers a reboot.
set +e
sudo "$REPO_ROOT/install.sh" "${INSTALL_ARGS[@]}" 2>&1 | tee "$LOG_FILE"
INSTALL_STATUS=${PIPESTATUS[0]}
set -e

if ((INSTALL_STATUS != 0)); then
    echo "Installation failed. Review: $LOG_FILE" >&2
    exit "$INSTALL_STATUS"
fi

echo "Installation succeeded. Log saved to: $LOG_FILE"
if [[ "$DO_REBOOT" == yes ]]; then
    echo "Rebooting now. Allow roughly 60 seconds for delayed GPU startup."
    sudo systemctl reboot
else
    echo "Run 'sudo reboot' when ready, wait about 60 seconds, then run:"
    echo "  $REPO_ROOT/scripts/verify.sh"
fi
