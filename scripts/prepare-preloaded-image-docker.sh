#!/usr/bin/env bash
# Purpose: Run the containerized repository/vendor preloading workflow.
# Platform: Linux/WSL2 host with Docker privileged image-mount support.
# Inputs: optional BASE_IMAGE, image/output directories, and pinned Docker image.
# Writes: a new preloaded image; the source image and repository are mounted read-only.
# Safety: requires generated vendor archives and refuses an existing output image.
# Repeat behavior: intentionally refuses to overwrite an existing derived image.
# Recovery: preserve the base image and rerun after removing only a verified partial.
# Verification: validate the preloaded image and continue with first-boot preparation.
set -Eeuo pipefail
REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BASE_IMAGE=${BASE_IMAGE:-}
BASE_IMAGE_DIR=${BASE_IMAGE_DIR:-$REPO_ROOT/work/images/armbian}
BASE_IMAGE_BASENAME=Armbian_26.8.1_Orangepizero3w_trixie_vendor_6.6.98_minimal
OUTPUT_DIR=${OUTPUT_DIR:-$REPO_ROOT/work/images/armbian}
DOCKER_IMAGE=${DOCKER_IMAGE:-orangepi-zero3w-setup/extraction-toolchain:bookworm-20260824}
command -v docker >/dev/null 2>&1 || { echo 'ERROR: docker is required' >&2; exit 1; }
docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1 || { echo "ERROR: Docker toolchain image is missing: $DOCKER_IMAGE; run make docker-toolchain" >&2; exit 1; }
if [[ -z $BASE_IMAGE ]]; then
    for candidate in \
        "$BASE_IMAGE_DIR/$BASE_IMAGE_BASENAME.img.xz" \
        "$BASE_IMAGE_DIR/$BASE_IMAGE_BASENAME.img" \
        "$BASE_IMAGE_DIR/$BASE_IMAGE_BASENAME.img.7z"; do
        if [[ -f $candidate ]]; then
            BASE_IMAGE=$candidate
            break
        fi
    done
fi
[[ -f $BASE_IMAGE ]] || { echo "ERROR: base image not found: $BASE_IMAGE" >&2; exit 1; }
[[ -f $REPO_ROOT/work/vendor-output/pvr-userspace.tar.gz ]] || { echo 'ERROR: generate vendor archives first' >&2; exit 1; }
name=${BASE_IMAGE##*/}; name=${name%.img.xz}; name=${name%.img.7z}; name=${name%.img}
OUTPUT_IMAGE="$OUTPUT_DIR/${name}-preloaded.img"
case "$BASE_IMAGE" in *.img.xz) FORMAT=xz;; *.img.7z) FORMAT=7z;; *) FORMAT=img;; esac
[[ ! -e $OUTPUT_IMAGE ]] || { echo "ERROR: output exists: $OUTPUT_IMAGE" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"
docker run --rm --privileged \
    -v "$REPO_ROOT:/repo:ro" -v "$BASE_IMAGE:/input/base:ro" \
    -v "$OUTPUT_DIR:/output" "$DOCKER_IMAGE" \
    bash /repo/scripts/prepare-preloaded-image-inner.sh \
    --base-image /input/base --base-format "$FORMAT" --output-image "/output/${OUTPUT_IMAGE##*/}"
