#!/usr/bin/env bash
# Purpose: Fetch pinned synthetic H.264/H.265 VPU fixtures from a GitHub release.
# Platform: Host or board with network access and repository testdata permissions.
# Inputs: Optional VPU_TESTDATA_TAG, --tag, and --force.
# Dependencies: Bash, curl, sha256sum, and the pinned release's SHA256SUMS asset.
# Writes: Downloaded MP4/framemd5 fixtures under testdata/videos; --force permits replacement.
# Safety: Verifies every downloaded asset against the release checksum before use.
# Repeat: Reuses existing verified files unless --force is supplied.
# Recovery: Remove only the generated testdata/videos fixtures and rerun with the pinned tag.
# Outputs: Fixture files, checksum verification output, and an exit status.
# Verification: Successful completion requires all downloaded files to match SHA256SUMS.
# Documentation: docs/optional/vpu.md
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
OUTPUT_DIR="$REPO_ROOT/testdata/videos"
TAG=${VPU_TESTDATA_TAG:-vpu-testdata-v1}
FORCE=no

usage() {
    cat <<'EOF'
Usage: sudo ./scripts/fetch-vpu-test-videos.sh [options]

Fetch individual synthetic VPU fixtures from a pinned GitHub release.

Options:
  --tag TAG       Release tag (default: vpu-testdata-v1)
  --force         Overwrite existing files
  -h, --help      Show this help
EOF
}

while (($#)); do
    case "$1" in
        --tag) TAG=${2:?missing tag after --tag}; shift 2 ;;
        --force) FORCE=yes; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

command -v curl >/dev/null 2>&1 || {
    echo 'ERROR: curl is required. Install it with: sudo apt install curl' >&2
    exit 1
}
command -v sha256sum >/dev/null 2>&1 || {
    echo 'ERROR: sha256sum is required. Install coreutils.' >&2
    exit 1
}

BASE_URL="https://github.com/wuclark/orangepi-zero3w-setup/releases/download/$TAG"
ASSETS=()
for source in mandelbrot testsrc rgbtestsrc life; do
    for geometry in 720p-30 1080p-60; do
        for codec in h264 h265; do
            ASSETS+=("$source-$codec-$geometry"'fps.mp4')
            ASSETS+=("$source-$codec-$geometry"'fps.md5')
        done
    done
done
ASSETS+=(combo-h264-720p-30fps.mp4 combo-h264-720p-30fps.md5)

mkdir -p "$OUTPUT_DIR"
for asset in SHA256SUMS "${ASSETS[@]}"; do
    destination="$OUTPUT_DIR/$asset"
    if [[ -s $destination && $FORCE != yes ]]; then
        echo "Keeping existing $destination"
    else
        echo "Fetching $asset from release $TAG"
        curl --fail --location --retry 3 --output "$destination" "$BASE_URL/$asset"
    fi
done

(cd "$OUTPUT_DIR" && sha256sum --ignore-missing -c SHA256SUMS)
echo "Fetched and verified synthetic VPU fixtures in $OUTPUT_DIR"
