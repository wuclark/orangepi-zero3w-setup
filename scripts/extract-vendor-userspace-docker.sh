#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
IMAGE_DIR=${IMAGE_DIR:-$REPO_ROOT/work/images}
OUTPUT_DIR=${OUTPUT_DIR:-$REPO_ROOT/work/vendor-output}
DOCKER_IMAGE=${DOCKER_IMAGE:-debian:bookworm-slim}
command -v docker >/dev/null 2>&1 || { echo 'ERROR: docker is required' >&2; exit 1; }
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
[[ ! -e $OUTPUT_DIR ]] || { echo "ERROR: output exists: $OUTPUT_DIR" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"
docker run --rm --privileged -v "$REPO_ROOT:/work" -w /work "$DOCKER_IMAGE" \
    bash /work/scripts/extract-vendor-userspace-image.sh \
    --gpu-vpu-image "/work/${GPU_VPU_IMAGE#"$REPO_ROOT/"}" \
    --npu-image "/work/${NPU_IMAGE#"$REPO_ROOT/"}" \
    --output-dir "/work/${OUTPUT_DIR#"$REPO_ROOT/"}"
