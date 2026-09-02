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
grep -q -- "--exclude='testdata/videos/\\*.mp4'" "$REPO_ROOT/scripts/prepare-preloaded-image-inner.sh"
grep -q -- "--exclude='testdata/videos/\\*.md5'" "$REPO_ROOT/scripts/prepare-preloaded-image-inner.sh"
grep -q -- "--exclude='testdata/videos/SHA256SUMS'" "$REPO_ROOT/scripts/prepare-preloaded-image-inner.sh"
grep -q 'mandelbrot-h264-720p-30fps.mp4' "$REPO_ROOT/scripts/prepare-preloaded-image-inner.sh"
grep -q 'mandelbrot-h265-720p-30fps.mp4' "$REPO_ROOT/scripts/prepare-preloaded-image-inner.sh"
grep -q 'orange-pi-6.6-sun60iw2' "$REPO_ROOT/scripts/prepare-kernel-source.sh"
grep -q 'kernel-source' "$REPO_ROOT/Makefile"
grep -q 'Using embedded checkout' "$REPO_ROOT/scripts/build-pvrsrvkm.sh"
grep -q -- '--decode-pair' "$REPO_ROOT/scripts/gen_test_videos.sh"
grep -q 'board-vpu-generate-decode-videos' "$REPO_ROOT/Makefile"
grep -q 'VENDOR_FILES_ROOT' "$REPO_ROOT/scripts/board-acceleration-workflow.sh"
grep -q '/opt/orangepi-zero3w-setup/vendor-files' "$REPO_ROOT/scripts/board-acceleration-workflow.sh"
grep -q 'sudo make board-gpu-compute-deps' "$REPO_ROOT/scripts/board-validation.sh"
grep -q 'sudo make remote-x11vnc' "$REPO_ROOT/scripts/board-validation.sh"
grep -q 'known limitation; Vulkan/EGL PowerVR are unaffected' "$REPO_ROOT/scripts/verify.sh"
grep -q 'board-headless-benchmark' "$REPO_ROOT/Makefile"
grep -q 'run-vulkan-compute-benchmark.sh' "$REPO_ROOT/scripts/board-headless-benchmark.sh"
grep -q 'test-vpu-decode.sh' "$REPO_ROOT/scripts/board-headless-benchmark.sh"
grep -q 'test-npu.sh' "$REPO_ROOT/scripts/board-headless-benchmark.sh"
grep -q 'board-status' "$REPO_ROOT/Makefile"
grep -q 'board-gpu-abi-check' "$REPO_ROOT/Makefile"
grep -q 'vermagic' "$REPO_ROOT/scripts/board-gpu-abi-check.sh"
grep -q 'Read-only status report complete' "$REPO_ROOT/scripts/board-status.sh"
grep -q 'thermal_throttle' "$REPO_ROOT/scripts/board-thermal-monitor.sh"
grep -q 'board-thermal-monitor' "$REPO_ROOT/Makefile"
grep -q 'Read-only storage health report complete' "$REPO_ROOT/scripts/board-storage-health.sh"
grep -q 'board-storage-health' "$REPO_ROOT/Makefile"
grep -q 'board-system-benchmark' "$REPO_ROOT/Makefile"
grep -q -- '--storage' "$REPO_ROOT/scripts/board-system-benchmark.sh"
grep -q -- '--network' "$REPO_ROOT/scripts/board-system-benchmark.sh"
grep -q '90-orangepi-xterm' "$REPO_ROOT/scripts/setup-desktop.sh"
grep -q 'XTerm\*foreground: white' "$REPO_ROOT/config/90-orangepi-xterm"

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
