#!/usr/bin/env bash
# Purpose: Extract allowlisted GPU/VPU/NPU userspace from source images in Docker.
# Platform: Linux/WSL2 host with Docker privileged loop/mount support.
# Inputs: source images, optional SHA-256 values, output directory, Docker image.
# Writes: generated private vendor archives and manifests under work/vendor-output.
# Safety: source images are mounted read-only and proprietary output stays untracked.
# Repeat behavior: regenerates or reuses output according to the extraction workflow.
# Recovery: preserve source images and inspect the Docker log before retrying.
# Verification: run tests/test-archives.sh and prepare-vendor-archives.sh.
set -Eeuo pipefail
REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
IMAGE_DIR=${IMAGE_DIR:-$REPO_ROOT/work/images}
OUTPUT_DIR=${OUTPUT_DIR:-$REPO_ROOT/work/vendor-output}
DOCKER_IMAGE=${DOCKER_IMAGE:-orangepi-zero3w-setup/extraction-toolchain:bookworm-20260824}
GPU_VPU_SHA256=${GPU_VPU_SHA256:-}
NPU_SHA256=${NPU_SHA256:-}
command -v docker >/dev/null 2>&1 || { echo 'ERROR: docker is required' >&2; exit 1; }
docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1 || { echo "ERROR: Docker toolchain image is missing: $DOCKER_IMAGE; run make docker-toolchain" >&2; exit 1; }
progress() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
find_image() {
    local label=$1 explicit=$2 pattern item
    shift 2
    if [[ -n $explicit ]]; then
        [[ -f $explicit ]] || { echo "ERROR: missing $label image: $explicit" >&2; exit 1; }
        printf '%s\n' "$explicit"; return
    fi
    local -a matches=()
    for pattern in "$@"; do
        while IFS= read -r -d '' item; do matches+=("$item"); done \
            < <(find "$IMAGE_DIR" -maxdepth 1 -type f -iname "$pattern" -print0)
    done
    if ((${#matches[@]} > 1)); then
        mapfile -t matches < <(printf '%s\n' "${matches[@]}" | sort -u)
    fi
    if ((${#matches[@]} != 1)); then
        echo "ERROR: expected exactly one $label image in $IMAGE_DIR; found ${#matches[@]}" >&2
        printf 'Accepted names:\n  %s\n' "$@" >&2; exit 1
    fi
    printf '%s\n' "${matches[0]}"
}
GPU_VPU_IMAGE=$(find_image 'GPU/VPU' "${GPU_VPU_IMAGE:-}" \
    'radxa-a733_bullseye_kde_r2.output_512.img' 'radxa-a733_bullseye_kde_r2.output_512.img.xz' \
    'radxa-a733_bullseye_kde_r2.output_512.img.7z')
NPU_IMAGE=$(find_image 'NPU' "${NPU_IMAGE:-}" \
    'Orangepizero3w_1.0.0_ubuntu_jammy_desktop_xfce_linux6.6.98.img' \
    'Orangepizero3w_1.0.0_ubuntu_jammy_desktop_xfce_linux6.6.98.7z' \
    'Orangepizero3w_1.0.0_ubuntu_jammy_desktop_xfce_linux6.6.98.img.xz')
verify_hash() {
    local label=$1 file=$2 expected=$3 actual
    [[ -z $expected ]] && return 0
    actual=$(sha256sum "$file" | awk '{print $1}')
    [[ ${actual,,} == ${expected,,} ]] || { echo "ERROR: $label checksum mismatch" >&2; exit 1; }
}
verify_hash GPU_VPU "$GPU_VPU_IMAGE" "$GPU_VPU_SHA256"
verify_hash NPU "$NPU_IMAGE" "$NPU_SHA256"
if [[ -e $OUTPUT_DIR ]]; then
    [[ -d $OUTPUT_DIR && -z $(find "$OUTPUT_DIR" -mindepth 1 ! -name .gitkeep -print -quit) ]] || {
        echo "ERROR: output must be absent or empty: $OUTPUT_DIR" >&2; exit 1;
    }
fi
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
progress "Starting Docker userspace extraction (GPU/VPU: $(basename "$GPU_VPU_IMAGE"), NPU: $(basename "$NPU_IMAGE"))"
docker run --rm --privileged \
    -v "$REPO_ROOT/scripts:/work/scripts:ro" \
    -v "$GPU_VPU_IMAGE:/input/gpu:ro" -v "$NPU_IMAGE:/input/npu:ro" \
    -v "$OUTPUT_DIR:/work/output" "$DOCKER_IMAGE" \
    bash /work/scripts/extract-vendor-userspace-image.sh \
    --gpu-vpu-image /input/gpu --npu-image /input/npu --output-dir /work/output
