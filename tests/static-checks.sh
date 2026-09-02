#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

while IFS= read -r script; do
    bash -n "$script"
done < <(find "$REPO_ROOT/scripts" "$REPO_ROOT/tests" -type f -name '*.sh' | sort)

grep -q '/dev/dri/card0' "$REPO_ROOT/config/10-sunxi-primary.conf"
grep -q 'ExecStartPre=/bin/sleep 30' "$REPO_ROOT/config/pvr-late-load.service"
grep -q '/opt/pvr-ddk-24.2/lib/libVK_IMG.so' "$REPO_ROOT/config/img_icd.json"
grep -q 'armbian-bootstrap.sh' "$REPO_ROOT/install.sh"
grep -q 'install-x11vnc.sh' "$REPO_ROOT/install.sh"
grep -q 'labwc' "$REPO_ROOT/scripts/setup-desktop.sh"
grep -q 'fluxbox' "$REPO_ROOT/scripts/setup-desktop.sh"
grep -q 'orangepi-session-launch' "$REPO_ROOT/scripts/setup-desktop.sh"
grep -q 'wayland-sessions/orangepi-' "$REPO_ROOT/scripts/setup-reset.sh"
grep -q 'build-pvrsrvkm.sh' "$REPO_ROOT/install.sh"
grep -q 'sudo.*install.sh' "$REPO_ROOT/armbian-startup.sh"
grep -q 'Copy-VendorArchives.ps1' "$REPO_ROOT/docs/legacy/fresh-armbian-install.md"
grep -q 'prepare-vendor-archives.sh' "$REPO_ROOT/install.sh"
grep -q '^\*\.tar.gz$' "$REPO_ROOT/.gitignore"
grep -q 'AGENTS.md' "$REPO_ROOT/CLAUDE.md"
grep -q 'scp.exe' "$REPO_ROOT/windows/Copy-PvrVendorRoot.ps1"
grep -q 'PowerVR B-Series BXM-4-64 MC1' "$REPO_ROOT/docs/legacy/step-by-step-gpu-guide.md"
grep -q 'spinning hardware-rendered vkcube' "$REPO_ROOT/TUTORIAL-ARTICLE.md"
grep -q '95-zero3w-vnc-tunnel' "$REPO_ROOT/scripts/install-x11vnc.sh"
grep -q '99-orangepi-zero3w-cedar.rules' "$REPO_ROOT/scripts/install-vpu-userspace.sh"
grep -q 'KERNEL=="cedar_dev\*"' "$REPO_ROOT/config/99-orangepi-zero3w-cedar.rules"
grep -q 'orangepi-tycat' "$REPO_ROOT/scripts/setup-desktop.sh"
grep -q 'orangepi-play-video' "$REPO_ROOT/scripts/setup-desktop.sh"

if grep -qs 'PRESET_HOSTNAME' "$REPO_ROOT/scripts/create-headless-preset.sh" \
    "$REPO_ROOT/windows/Prepare-HeadlessPreset.ps1"; then
    echo 'Unsupported Armbian first-boot hostname preset found' >&2
    exit 1
fi

if grep -Rqs '/etc/modules-load.d/pvrsrvkm.conf' "$REPO_ROOT/config"; then
    echo 'Unsafe modules-load configuration found' >&2
    exit 1
fi

echo 'Static checks passed.'
