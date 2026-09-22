#!/usr/bin/env bash
# Purpose: Restore a full offline bundle created by create-offline-bundle.sh into a checkout.
# Platform: Host checkout (Linux/WSL2); reads a bundle directory produced by make fullbackup.
# Inputs: BACKUP_DIR or --backup, RESTORE_SET=required|cache|sensitive|all or --set,
#   --force to skip the generic confirmation (never skips the sensitive one).
# Writes: Repository input/cache/sensitive paths selected by the requested set.
# Safety: verifies SHA256SUMS before extracting anything; rejects unsafe tar members
#   and absolute/outside paths; sensitive restores always require typed confirmation.
# Repeat: overwrites matching restored paths only after confirmation (or --force).
# Recovery: keep the original bundle; rerun with the correct set if interrupted.
# Outputs: Verification result, extracted set list, and next-step hints (make test, make newsd).
# Verification: rerun `sha256sum -c SHA256SUMS` in the bundle, inspect restored files,
#   then run `make test` or the relevant build.
# Documentation: docs/reference/input-sources.md
set -Eeuo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BACKUP_DIR=${BACKUP_DIR:-}
RESTORE_SET=${RESTORE_SET:-}

usage() {
    cat >&2 <<'EOF'
Usage:
  make fullrestore BACKUP_DIR=/path/to/bundle [RESTORE_SET=required|cache|sensitive|all]
  ./scripts/restore-offline-bundle.sh --backup /path/to/bundle [--set required|cache|sensitive|all] [--force]

Verifies SHA256SUMS first, then extracts only the requested set(s) into the checkout.
Sensitive restores always prompt (type RESTORE SENSITIVE) unless RESTORE_FORCE=1
is set explicitly for a controlled re-provision.
Fully offline checkout (no GitHub access needed):
  git clone /path/to/bundle/repo.bundle orangepi-zero3w-setup
  cd orangepi-zero3w-setup
  git remote set-url origin https://github.com/wuclark/orangepi-zero3w-setup.git
  make fullrestore BACKUP_DIR=/path/to/bundle
EOF
}

while (($#)); do
    case "$1" in
        --backup) BACKUP_DIR=${2:?}; shift 2;;
        --set) RESTORE_SET=${2:?}; shift 2;;
        --force) RESTORE_FORCE=1; shift;;
        -h|--help) usage; exit 0;;
        *) echo "ERROR: unknown option: $1" >&2; usage; exit 2;;
    esac
done

[[ -n "$BACKUP_DIR" ]] || { echo 'ERROR: set BACKUP_DIR=/path/to/bundle.' >&2; usage; exit 2; }
[[ -d "$BACKUP_DIR" ]] || { echo "ERROR: bundle directory not found: $BACKUP_DIR" >&2; exit 2; }
RESTORE_SET=${RESTORE_SET:-all}
case "$RESTORE_SET" in required|cache|sensitive|all) ;; *) echo 'ERROR: choose RESTORE_SET=required, cache, sensitive, or all.' >&2; usage; exit 2;; esac

[[ -f "$BACKUP_DIR/SHA256SUMS" ]] || { echo "ERROR: SHA256SUMS is missing in: $BACKUP_DIR" >&2; exit 2; }
(cd "$BACKUP_DIR" && sha256sum -c SHA256SUMS >/dev/null) || {
    echo 'ERROR: bundle checksum verification failed; refusing to restore.' >&2
    exit 1
}

sets=("$RESTORE_SET")
[[ "$RESTORE_SET" == all ]] && sets=(required cache sensitive)

# Resolve archive names for the bundle's compression (gzip default, xz/none opt-in).
bundle_archive() {
    local set_name=$1 candidate
    for candidate in "$BACKUP_DIR/$set_name.tar.gz" "$BACKUP_DIR/$set_name.tar.xz" "$BACKUP_DIR/$set_name.tar"; do
        if [[ -f $candidate ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

for set_name in "${sets[@]}"; do
    [[ $set_name == sensitive ]] && continue
    bundle_archive "$set_name" >/dev/null || {
        [[ $set_name == required ]] || continue
        echo "ERROR: required bundle archive is missing: $set_name.tar.gz (.xz/.tar)" >&2
        exit 2
    }
done
if [[ " ${sets[*]} " == *" sensitive "* ]]; then
    if ! bundle_archive sensitive >/dev/null; then
        echo 'INFO: bundle has no sensitive set; skipping it.' >&2
        sets=("${sets[@]/sensitive}")
    fi
fi

if [[ " ${sets[*]} " == *" sensitive "* ]]; then
    if [[ ${RESTORE_FORCE:-} != 1 ]]; then
        if [[ ! -t 0 ]]; then
            echo 'ERROR: sensitive restore requires RESTORE_FORCE=1 on non-interactive runs.' >&2
            exit 2
        fi
        read -r -p 'This restores passwords and Wi-Fi credentials. Type RESTORE SENSITIVE to continue: ' confirmation
        [[ "$confirmation" == 'RESTORE SENSITIVE' ]] || { echo 'Sensitive restore cancelled.' >&2; exit 2; }
    fi
fi

if [[ ${RESTORE_FORCE:-} != 1 ]]; then
    if [[ ! -t 0 ]]; then
        echo "ERROR: non-interactive restore requires RESTORE_FORCE=1. Sets: ${sets[*]} -> $REPO_ROOT" >&2
        exit 2
    fi
    echo "The following bundle set(s) will be restored into: $REPO_ROOT"
    printf '  %s\n' "${sets[@]}"
    read -r -p 'Type RESTORE to continue: ' confirmation
    [[ "$confirmation" == RESTORE ]] || { echo 'Restore cancelled.' >&2; exit 2; }
fi

for set_name in "${sets[@]}"; do
    archive=$(bundle_archive "$set_name") || continue
    echo "Restoring $set_name from $(basename "$archive")..."
    # List members first and reject absolute paths or parent escapes before extraction.
    if tar -tf "$archive" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
        echo "ERROR: unsafe path in bundle archive: $archive" >&2
        exit 1
    fi
    tar -C "$REPO_ROOT" -xf "$archive"
done

(cd "$BACKUP_DIR" && sha256sum -c SHA256SUMS >/dev/null)
echo "Restore complete: $RESTORE_SET"

# Git history: the bundle carries repo.bundle so an offline checkout can still
# pull from GitHub later. A clone made from the bundle points origin at the
# bundle file; retargeting it is config-only and works offline.
if [[ -f "$BACKUP_DIR/repo.bundle" ]]; then
    if [[ ! -d "$REPO_ROOT/.git" ]]; then
        echo 'INFO: this checkout has no .git history; to gain it offline:' >&2
        echo "  git clone \"$BACKUP_DIR/repo.bundle\" /tmp/zero3w-history && \\" >&2
        echo '    mv /tmp/zero3w-history/.git "$REPO_ROOT/.git" && rm -rf /tmp/zero3w-history' >&2
    elif [[ $(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || echo '') == *repo.bundle* ]]; then
        git -C "$REPO_ROOT" remote set-url origin https://github.com/wuclark/orangepi-zero3w-setup.git
        echo 'INFO: origin retargeted to https://github.com/wuclark/orangepi-zero3w-setup.git (git pull works once online).' >&2
    elif ! git -C "$REPO_ROOT" remote get-url origin >/dev/null 2>&1; then
        git -C "$REPO_ROOT" remote add origin https://github.com/wuclark/orangepi-zero3w-setup.git
        echo 'INFO: origin added for https://github.com/wuclark/orangepi-zero3w-setup.git.' >&2
    fi
else
    echo 'INFO: bundle has no repo.bundle; git history is unavailable offline.' >&2
fi
echo 'Next: run `make test`, then `make newsd` to rebuild derived images.'
