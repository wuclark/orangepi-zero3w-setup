#!/usr/bin/env bash
# Purpose: Create a portable full offline bundle: repo snapshot plus every private image/vendor input.
# Platform: Host checkout (Linux/WSL2); destination may be local removable or network storage.
# Inputs: BACKUP_DIR or --destination/--output, INCLUDE_SENSITIVE=YES or --include-sensitive,
#   BUNDLE_COMPRESS=gzip|xz|none or --compression, --force to reuse a non-empty destination.
# Writes: bundle-info.txt, repo-snapshot.tar.gz, repo.bundle (full git history),
#   required.tar.gz, cache.tar.gz,
#   optionally sensitive.tar.gz, per-archive .files.txt lists, and top-level SHA256SUMS.
# Safety: never commits proprietary files; refuses repo root as destination; credentials only
#   with INCLUDE_SENSITIVE=YES plus typed BACKUP SENSITIVE confirmation; final firstboot
#   images are credential-bearing and stay in the sensitive set.
# Repeat: safe to rerun; refuses to overwrite an existing bundle without --force.
# Recovery: keep the bundle outside Git; restore with scripts/restore-offline-bundle.sh
#   (checksums verified before any copy); encrypt before any network copy when sensitive.
# Outputs: Timestamped progress lines with sizes, then the bundle path and SHA256SUMS.
# Verification: inspect SHA256SUMS with `sha256sum -c`, then restore to a temp checkout
#   and run `make test`. See docs/reference/input-sources.md for the input inventory.
# Documentation: docs/development/data-lifecycle.md
set -Eeuo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BACKUP_DIR=${BACKUP_DIR:-}
INCLUDE_SENSITIVE=${INCLUDE_SENSITIVE:-no}
BUNDLE_COMPRESS=${BUNDLE_COMPRESS:-gzip}
FORCE=0

# Single source of truth for bundle coverage. New images or vendor files that
# arrive under these roots and extensions are picked up automatically without
# editing the archiving logic below. tests/test-bundle-manifest.sh asserts
# every .gitignore-d vendor/image extension has a covering pattern here.
# Required: hard-to-replace rebuild inputs (source images, SDK, kernel source).
REQUIRED_PATTERNS=(
    'work/images/Orangepizero3w_*.img'
    'work/images/Orangepizero3w_*.img.xz'
    'work/images/Orangepizero3w_*.img.7z'
    'work/images/radxa-*.img'
    'work/images/radxa-*.img.xz'
    'work/images/radxa-*.img.7z'
    'work/images/ai-sdk.tar.gz'
    'work/images/docker_images_*.zip'
    'work/images/*.onnx'
    'work/images/armbian/*minimal.img'
    'work/images/armbian/*minimal.img.xz'
    'build-pvrsrvkm/linux-orangepi'
    'work/sources/*'
    'vendor-files/*'
    'vendor-root/*'
)
# Cache: rebuildable outputs (generated archives, derived preloaded images).
# Credential-bearing firstboot images are intentionally NOT here; they belong
# to the sensitive set below.
CACHE_PATTERNS=(
    'work/vendor-output/*'
    'work/images/armbian/*preloaded.img'
    'work/images/armbian/*preloaded.img.sha256'
    'work/images/armbian/*preloaded.img.manifest.txt'
    'work/images/armbian/.last-final-image'
    'testdata/videos/*'
)
# Sensitive: credential-bearing local inputs. Only bundled with explicit opt-in.
SENSITIVE_PATTERNS=(
    'not_logged_in_yet'
    'provisioning.sh'
    'work/images/armbian/*firstboot*.img'
    'work/images/armbian/*firstboot*.img.sha256'
)

usage() {
    cat >&2 <<'EOF'
Usage:
  make fullbackup BACKUP_DIR=/path/to/bundle [INCLUDE_SENSITIVE=YES] [BUNDLE_COMPRESS=gzip|xz|none]
  ./scripts/create-offline-bundle.sh --destination /path/to/bundle [--include-sensitive] [--compression gzip|xz|none] [--force]

What it backs up (full offline kit, gzip default):
  repo snapshot (git archive HEAD) + repo.bundle (full git history for
            offline clone + later git pull) + VERSION + reference-stack.env identity
  required: Orange Pi source image, Radxa source image, Armbian base image,
            ai-sdk.tar.gz, ACUITY zip, public ResNet50 ONNX, kernel source,
            work/sources/*, vendor-files/ and vendor-root/ when present
  cache: work/vendor-output/*, derived preloaded image + checksums, VPU fixtures
  sensitive (ONLY with --include-sensitive / INCLUDE_SENSITIVE=YES):
            not_logged_in_yet, provisioning.sh, credential-bearing firstboot images

New images or vendor files under work/images/, vendor-files/, vendor-root/,
work/vendor-output/, or work/sources/ are picked up automatically by pattern;
no script change is needed for a new file of a known kind.

Restore:
  make fullrestore BACKUP_DIR=/path/to/bundle [RESTORE_SET=required|cache|sensitive|all]
  ./scripts/restore-offline-bundle.sh --backup /path/to/bundle --set all
  (verifies SHA256SUMS before copying anything; sensitive restores re-prompt)
Fully offline checkout (no GitHub access needed):
  git clone /path/to/bundle/repo.bundle orangepi-zero3w-setup
  cd orangepi-zero3w-setup
  git remote set-url origin https://github.com/wuclark/orangepi-zero3w-setup.git
  make fullrestore BACKUP_DIR=/path/to/bundle
  (origin retargeting is config-only and works offline; git pull works once online)

Compression: gzip is the default (fast; raw .img files shrink ~30-50%).
  Already-compressed inputs (.tar.gz/.zip/.onnx) barely shrink further.
  Use --compression xz for a smaller, much slower bundle, or none for speed.
EOF
}

progress() {
    printf '[%s] [%s] %s\n' "offline-bundle" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

while (($#)); do
    case "$1" in
        --destination|--output) BACKUP_DIR=${2:?}; shift 2;;
        --include-sensitive) INCLUDE_SENSITIVE=YES; shift;;
        --compression) BUNDLE_COMPRESS=${2:?}; shift 2;;
        --force) FORCE=1; shift;;
        -h|--help) usage; exit 0;;
        *) echo "ERROR: unknown option: $1" >&2; usage; exit 2;;
    esac
done

if [[ -z "$BACKUP_DIR" ]]; then
    if [[ -t 0 ]]; then
        read -r -p 'Backup destination: ' BACKUP_DIR
    fi
    [[ -n "$BACKUP_DIR" ]] || { echo 'ERROR: BACKUP_DIR is required.' >&2; usage; exit 2; }
fi

case "$BUNDLE_COMPRESS" in
    gzip|xz|none) ;;
    *) echo "ERROR: BUNDLE_COMPRESS must be gzip, xz, or none." >&2; usage; exit 2;;
esac

# Resolve to an absolute path without requiring the directory to exist yet.
BACKUP_DIR=$(printf '%s' "$BACKUP_DIR" | sed 's:/*$::')
case "$BACKUP_DIR" in
    /*) ;;
    *) BACKUP_DIR="$PWD/$BACKUP_DIR";;
esac

if [[ "$BACKUP_DIR" == "$REPO_ROOT" ]]; then
    echo 'ERROR: refusing to write the bundle into the repository root.' >&2
    exit 2
fi
case "$BACKUP_DIR/" in
    "$REPO_ROOT"/*)
        echo 'ERROR: refusing to write the bundle inside the checkout (it would recurse). Choose a path outside the repo.' >&2
        exit 2
        ;;
esac

sensitive_requested=0
case "$INCLUDE_SENSITIVE" in
    YES|yes|1|true) sensitive_requested=1;;
esac

if ((sensitive_requested)); then
    if [[ ${BACKUP_CONFIRM:-} != YES ]]; then
        if [[ ! -t 0 ]]; then
            echo 'ERROR: sensitive bundle requires BACKUP_CONFIRM=YES on non-interactive runs.' >&2
            exit 2
        fi
        read -r -p 'This includes passwords and Wi-Fi credentials. Type BACKUP SENSITIVE to continue: ' confirmation
        [[ "$confirmation" == 'BACKUP SENSITIVE' ]] || { echo 'Sensitive bundle cancelled.' >&2; exit 2; }
    fi
fi

mkdir -p "$BACKUP_DIR"
if ((FORCE == 0)) && [[ -n $(ls -A "$BACKUP_DIR" 2>/dev/null) ]]; then
    echo "ERROR: destination is not empty: $BACKUP_DIR (use --force to reuse it)." >&2
    exit 2
fi

collect_matches() {
    # $1 = name of output array, remaining args = relative glob patterns.
    local -n out=$1
    shift
    local pattern match
    out=()
    for pattern in "$@"; do
        shopt -s nullglob dotglob
        # shellcheck disable=SC2206
        local -a hits=($REPO_ROOT/$pattern)
        shopt -u nullglob dotglob
        for match in "${hits[@]}"; do
            # Skip credential rotation backups; only the live files bundle.
            case "${match##*/}" in
                *.previous.*) continue;;
            esac
            # Skip gitkeep placeholders and manifests of manifests.
            case "${match##*/}" in
                .gitkeep) continue;;
            esac
            out+=("${match#"$REPO_ROOT/"}")
        done
    done
}

require_any() {
    # Fail closed when a whole required family is absent (e.g. no source image at all).
    local label=$1
    shift
    local -a items=("$@")
    ((beans=${#items[@]})) || true
    if ((${#items[@]} == 0)); then
        echo "ERROR: required bundle input is missing: $label" >&2
        case "$label" in
            'Orange Pi source image'|'Radxa source image'|'Armbian base image')
                echo 'ACTION: place the matching source image under work/images/ (see docs/reference/input-sources.md), then rerun.' >&2;;
            'AI SDK')
                echo 'ACTION: place the AI SDK archive at work/images/ai-sdk.tar.gz, then rerun.' >&2;;
            'matching kernel source')
                echo 'ACTION: run `make kernel-source`, then rerun this backup.' >&2;;
        esac
        return 1
    fi
}

GIT_REVISION=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
RELEASE_VERSION=$(cat "$REPO_ROOT/VERSION" 2>/dev/null || echo unknown)

progress "Collecting required inputs..."
declare -a required_files=()
collect_matches required_files "${REQUIRED_PATTERNS[@]}"
# Family-level presence gates so a typo'd download directory fails fast.
declare -a orange_pi=() radxa=() armbian_base=() ai_sdk=() kernel_src=()
collect_matches orange_pi 'work/images/Orangepizero3w_*.img' 'work/images/Orangepizero3w_*.img.xz' 'work/images/Orangepizero3w_*.img.7z'
collect_matches radxa 'work/images/radxa-*.img' 'work/images/radxa-*.img.xz' 'work/images/radxa-*.img.7z'
collect_matches armbian_base 'work/images/armbian/*minimal.img' 'work/images/armbian/*minimal.img.xz'
collect_matches ai_sdk 'work/images/ai-sdk.tar.gz'
collect_matches kernel_src 'build-pvrsrvkm/linux-orangepi'
require_any 'Orange Pi source image' "${orange_pi[@]}"
require_any 'Radxa source image' "${radxa[@]}"
require_any 'Armbian base image' "${armbian_base[@]}"
require_any 'AI SDK' "${ai_sdk[@]}"
require_any 'matching kernel source' "${kernel_src[@]}"

progress "Collecting rebuildable cache outputs..."
declare -a cache_files=()
collect_matches cache_files "${CACHE_PATTERNS[@]}"
if ((${#cache_files[@]} == 0)); then
    echo 'INFO: cache outputs are absent; run `make extract` to regenerate vendor archives.' >&2
fi

declare -a sensitive_files=()
if ((sensitive_requested)); then
    progress "Collecting credential-bearing inputs (sensitive opt-in)..."
    collect_matches sensitive_files "${SENSITIVE_PATTERNS[@]}"
    if ((${#sensitive_files[@]} == 0)); then
        echo 'INFO: no sensitive files are present; continuing without a sensitive set.' >&2
        sensitive_requested=0
    fi
fi

# Optional inputs are reported, never fatal: ACUITY zip, public ONNX, NPU driver.
for optional in 'work/images/docker_images_*.zip' 'work/images/*.onnx' 'work/sources/*'; do
    shopt -s nullglob
    # shellcheck disable=SC2206
    hits=($REPO_ROOT/$optional)
    shopt -u nullglob
    ((${#hits[@]})) || echo "INFO: optional input absent ($optional); bundle continues without it." >&2
done

tar_one() {
    # tar_one <output-archive> <compression> <file...>: stream repo-relative paths.
    local output=$1 compression=$2
    shift 2
    (($#)) || return 0
    progress "Archiving $(basename "$output") ($# paths, $compression)..."
    case "$compression" in
        gzip) tar -C "$REPO_ROOT" -czf "$output" "$@" ;;
        xz) tar -C "$REPO_ROOT" -cJf "$output" "$@" ;;
        none) tar -C "$REPO_ROOT" -cf "$output" "$@" ;;
    esac
    printf '%s\n' "$@" >"$output.files.txt"
}

progress "Writing repo snapshot (git archive HEAD)..."
case "$BUNDLE_COMPRESS" in
    gzip) git -C "$REPO_ROOT" archive --format=tar HEAD | gzip -6 >"$BACKUP_DIR/repo-snapshot.tar.gz" ;;
    xz) git -C "$REPO_ROOT" archive --format=tar HEAD | xz -T0 -6 >"$BACKUP_DIR/repo-snapshot.tar.xz" ;;
    none) git -C "$REPO_ROOT" archive --format=tar -o "$BACKUP_DIR/repo-snapshot.tar" HEAD ;;
esac

progress "Writing repo history bundle (git bundle --all, for offline clone)..."
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$REPO_ROOT" bundle create "$BACKUP_DIR/repo.bundle" --all
else
    echo 'WARNING: checkout has no .git history; skipping repo.bundle (snapshot above is still complete).' >&2
fi

case "$BUNDLE_COMPRESS" in
    gzip) suffix=tar.gz ;;
    xz) suffix=tar.xz ;;
    none) suffix=tar ;;
esac

tar_one "$BACKUP_DIR/required.$suffix" "$BUNDLE_COMPRESS" ${required_files[@]+"${required_files[@]}"}
tar_one "$BACKUP_DIR/cache.$suffix" "$BUNDLE_COMPRESS" ${cache_files[@]+"${cache_files[@]}"}
if ((sensitive_requested)); then
    mkdir -p -m 700 "$BACKUP_DIR"
    tar_one "$BACKUP_DIR/sensitive.$suffix" "$BUNDLE_COMPRESS" "${sensitive_files[@]}"
    chmod 600 "$BACKUP_DIR/sensitive.$suffix" "$BACKUP_DIR/sensitive.$suffix.files.txt"
fi

{
    printf 'backup_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'repository=%s\n' "$REPO_ROOT"
    printf 'git_revision=%s\n' "$GIT_REVISION"
    printf 'release_version=%s\n' "$RELEASE_VERSION"
    printf 'compression=%s\n' "$BUNDLE_COMPRESS"
    printf 'include_sensitive=%s\n' "$([ "$sensitive_requested" -eq 1 ] && echo YES || echo no)"
    printf 'required_paths=%d\n' "${#required_files[@]}"
    printf 'cache_paths=%d\n' "${#cache_files[@]}"
    printf 'sensitive_paths=%d\n' "${#sensitive_files[@]}"
    if [[ -f $BACKUP_DIR/repo.bundle ]]; then
        printf 'repo_bundle=%s\n' "$(sha256sum "$BACKUP_DIR/repo.bundle" | awk '{print $1}')"
    else
        printf 'repo_bundle=absent\n'
    fi
    if [[ -f "$REPO_ROOT/manifests/reference-stack.env" ]]; then
        printf 'reference_stack_mtime=%s\n' "$(stat -c %y "$REPO_ROOT/manifests/reference-stack.env" 2>/dev/null || echo unknown)"
    fi
} >"$BACKUP_DIR/bundle-info.txt"
chmod 600 "$BACKUP_DIR/bundle-info.txt"

(cd "$BACKUP_DIR" && sha256sum bundle-info.txt repo-snapshot.tar* repo.bundle required."$suffix" cache."$suffix" 2>/dev/null >SHA256SUMS)
if ((sensitive_requested)); then
    (cd "$BACKUP_DIR" && sha256sum sensitive."$suffix" >>SHA256SUMS)
fi
(cd "$BACKUP_DIR" && sha256sum -c SHA256SUMS >/dev/null)

du -sh "$BACKUP_DIR" >&2 || true
progress "Bundle complete: $BACKUP_DIR (compression=$BUNDLE_COMPRESS, sensitive=$([ "$sensitive_requested" -eq 1 ] && echo YES || echo no))"
printf '%s\n' "Verify:   (cd \"$BACKUP_DIR\" && sha256sum -c SHA256SUMS)"
printf '%s\n' "Restore:  make fullrestore BACKUP_DIR=\"$BACKUP_DIR\""
