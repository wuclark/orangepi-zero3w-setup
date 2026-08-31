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
grep -q 'build-pvrsrvkm.sh' "$REPO_ROOT/install.sh"
grep -q 'sudo.*install.sh' "$REPO_ROOT/armbian-startup.sh"
grep -q 'Copy-VendorArchives.ps1' "$REPO_ROOT/docs/FRESH-ARMBIAN-INSTALL.md"
grep -q 'prepare-vendor-archives.sh' "$REPO_ROOT/install.sh"
grep -q '^\*\.tar.gz$' "$REPO_ROOT/.gitignore"
grep -q 'AGENTS.md' "$REPO_ROOT/CLAUDE.md"
grep -q 'scp.exe' "$REPO_ROOT/windows/Copy-PvrVendorRoot.ps1"
grep -q 'PowerVR B-Series BXM-4-64 MC1' "$REPO_ROOT/docs/STEP-BY-STEP-GUIDE.md"
grep -q 'spinning hardware-rendered vkcube' "$REPO_ROOT/TUTORIAL-ARTICLE.md"

if grep -Rqs '/etc/modules-load.d/pvrsrvkm.conf' "$REPO_ROOT/config"; then
    echo 'Unsafe modules-load configuration found' >&2
    exit 1
fi

echo 'Static checks passed.'
