#!/usr/bin/env bash
# Purpose: Run the containerized first-boot image preparation workflow.
# Platform: Linux/WSL2 host with Docker privileged image-mount support.
# Inputs: optional INPUT_IMAGE, PRESET_FILE, PROVISIONING_FILE, and output overrides.
# Writes: a new first-boot image beside the preloaded image; source files are read-only.
# Safety: requires the pinned extraction image and refuses an existing output file.
# Repeat behavior: intentionally refuses to overwrite; choose a new output or remove it.
# Recovery: preserve the base image and recreate the derived output after failure.
# Verification: run validate-image-before-write.sh before writing an SD card.
set -Eeuo pipefail
REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
INPUT_IMAGE=${INPUT_IMAGE:-}
IMAGE_DIR=${IMAGE_DIR:-$REPO_ROOT/work/images/armbian}
PRELOADED_BASENAME=Armbian_26.8.1_Orangepizero3w_trixie_vendor_6.6.98_minimal-preloaded
PRESET_FILE=${PRESET_FILE:-$REPO_ROOT/not_logged_in_yet}
PROVISIONING_FILE=${PROVISIONING_FILE:-$REPO_ROOT/provisioning.sh}
OUTPUT_DIR=${OUTPUT_DIR:-$IMAGE_DIR}
DOCKER_IMAGE=${DOCKER_IMAGE:-orangepi-zero3w-setup/extraction-toolchain:bookworm-20260824}

usage() {
    cat <<EOF
Usage: $0

Create a final first-boot image from the exact preloaded Armbian image.
Environment overrides: INPUT_IMAGE, IMAGE_DIR, PRESET_FILE, PROVISIONING_FILE,
OUTPUT_DIR, DOCKER_IMAGE.
EOF
}
if [[ ${1:-} == -h || ${1:-} == --help ]]; then usage; exit 0; fi
command -v docker >/dev/null 2>&1 || { echo 'ERROR: docker is required' >&2; exit 1; }
docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1 || { echo "ERROR: Docker toolchain image is missing: $DOCKER_IMAGE; run make docker-toolchain" >&2; exit 1; }
if [[ -z $INPUT_IMAGE ]]; then
    for candidate in \
        "$IMAGE_DIR/$PRELOADED_BASENAME.img" \
        "$IMAGE_DIR/$PRELOADED_BASENAME.img.xz" \
        "$IMAGE_DIR/$PRELOADED_BASENAME.img.7z"; do
        if [[ -f $candidate ]]; then INPUT_IMAGE=$candidate; break; fi
    done
fi
[[ -f $INPUT_IMAGE ]] || { echo "ERROR: preloaded image not found: $INPUT_IMAGE" >&2; exit 1; }
[[ -f $PRESET_FILE ]] || { echo "ERROR: preset not found: $PRESET_FILE (create it with scripts/create-headless-preset.sh)" >&2; exit 1; }
[[ -f $PROVISIONING_FILE ]] || { echo "ERROR: provisioning hook not found: $PROVISIONING_FILE" >&2; exit 1; }
name=${INPUT_IMAGE##*/}; name=${name%.img.xz}; name=${name%.img.7z}; name=${name%.img}
OUTPUT_IMAGE="$OUTPUT_DIR/${name}-firstboot.img"
case "$INPUT_IMAGE" in *.img.xz) FORMAT=xz;; *.img.7z) FORMAT=7z;; *) FORMAT=img;; esac
[[ ! -e $OUTPUT_IMAGE ]] || { echo "ERROR: output exists: $OUTPUT_IMAGE" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"
docker run --rm --privileged \
    -v "$REPO_ROOT:/repo:ro" -v "$INPUT_IMAGE:/input/base:ro" \
    -v "$PRESET_FILE:/input/preset:ro" -v "$PROVISIONING_FILE:/input/provisioning:ro" \
    -v "$OUTPUT_DIR:/output" "$DOCKER_IMAGE" \
    bash /repo/scripts/prepare-firstboot-image-inner.sh \
    --base-image /input/base --base-format "$FORMAT" \
    --preset /input/preset --provisioning /input/provisioning \
    --output-image "/output/${OUTPUT_IMAGE##*/}"
