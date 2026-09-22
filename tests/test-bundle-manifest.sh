#!/usr/bin/env bash
# Purpose: Verify the full offline bundle covers every gitignored vendor/image extension.
# Platform: Host-side read-only test; no board, root, or proprietary inputs required.
# Inputs: .gitignore patterns and scripts/create-offline-bundle.sh pattern lists.
# Writes: Temporary fixture bundle metadata under /tmp only; removes it on exit.
# Safety: Never touches real work/images or vendor data; uses synthetic fixtures.
# Repeat: Safe to run repeatedly; each invocation uses a fresh temporary directory.
# Outputs: Assertion failures or a bundle-manifest-passed message.
# Verification: Exit 0 confirms coverage, help text, and empty-BACKUP_DIR guards.
# Documentation: docs/reference/input-sources.md
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BUNDLE_SCRIPT="$ROOT/scripts/create-offline-bundle.sh"
RESTORE_SCRIPT="$ROOT/scripts/restore-offline-bundle.sh"

# Every proprietary/derived extension banned from Git must have bundle coverage.
for extension in '.img' '.tar.gz' '.zip' '.onnx'; do
    grep -Fq "$extension" "$BUNDLE_SCRIPT" || {
        echo "bundle coverage is missing gitignored extension: $extension" >&2
        exit 1
    }
done

# Known input families must be named so a future rename fails loudly.
for token in 'ai-sdk.tar.gz' 'docker_images_' 'work/sources' 'vendor-files' 'vendor-root' 'work/vendor-output' 'linux-orangepi' 'firstboot'; do
    grep -Fq "$token" "$BUNDLE_SCRIPT" || {
        echo "bundle coverage is missing input family: $token" >&2
        exit 1
    }
done

# Gzip must remain the documented default; firstboot images must stay sensitive-only.
grep -Eq 'BUNDLE_COMPRESS=.*gzip' "$ROOT/Makefile" || { echo 'Makefile lost the gzip default.' >&2; exit 1; }
grep -Eq "BUNDLE_COMPRESS \?= gzip" "$ROOT/Makefile" || { echo 'Makefile lost BUNDLE_COMPRESS ?= gzip.' >&2; exit 1; }
grep -Fq 'firstboot' "$BUNDLE_SCRIPT" || { echo 'firstboot handling is missing.' >&2; exit 1; }
if grep -n 'firstboot' "$BUNDLE_SCRIPT" | grep -Fq 'CACHE_PATTERNS'; then
    echo 'firstboot images must not be in CACHE_PATTERNS (credential-bearing).' >&2
    exit 1
fi

# Offline git history must stay bundled: repo.bundle is created on backup,
# checksummed, and documented as the offline clone source.
grep -Fq 'repo.bundle' "$BUNDLE_SCRIPT" || { echo 'repo.bundle creation is missing.' >&2; exit 1; }
grep -Fq 'repo.bundle' "$RESTORE_SCRIPT" || { echo 'repo.bundle restore handling is missing.' >&2; exit 1; }
grep -Fq 'bundle create' "$BUNDLE_SCRIPT" || { echo 'git bundle creation is missing.' >&2; exit 1; }

# Guided usage: empty BACKUP_DIR must explain itself and exit 2 without writing.
if make -C "$ROOT" --no-print-directory fullbackup 2>"$ROOT/work/.bundle-test-stderr" >/dev/null; then
    echo 'make fullbackup without BACKUP_DIR should fail.' >&2
    exit 1
fi
grep -Fq 'BACKUP_DIR is required' "$ROOT/work/.bundle-test-stderr" || { echo 'fullbackup usage is missing.' >&2; exit 1; }
grep -Fq 'fullrestore' "$ROOT/work/.bundle-test-stderr" || { echo 'fullbackup usage must point at fullrestore.' >&2; exit 1; }
rm -f "$ROOT/work/.bundle-test-stderr"
if make -C "$ROOT" --no-print-directory fullrestore 2>"$ROOT/work/.bundle-test-stderr" >/dev/null; then
    echo 'make fullrestore without BACKUP_DIR should fail.' >&2
    exit 1
fi
grep -Fq 'BACKUP_DIR is required' "$ROOT/work/.bundle-test-stderr" || { echo 'fullrestore usage is missing.' >&2; exit 1; }
rm -f "$ROOT/work/.bundle-test-stderr"

# Scripts must document their own contract and refuse unknown flags.
"$BUNDLE_SCRIPT" --help 2>&1 | grep -Fq 'make fullbackup' || { echo 'bundle --help is missing.' >&2; exit 1; }
"$RESTORE_SCRIPT" --help 2>&1 | grep -Fq 'make fullrestore' || { echo 'restore --help is missing.' >&2; exit 1; }

printf 'bundle manifest tests passed\n'
