#!/usr/bin/env bash
set -Eeuo pipefail
GPU_VPU_IMAGE=""; NPU_IMAGE=""; OUTPUT_DIR=""
while (($#)); do
    case "$1" in
        --gpu-vpu-image) GPU_VPU_IMAGE=${2:?}; shift 2;;
        --npu-image) NPU_IMAGE=${2:?}; shift 2;;
        --output-dir) OUTPUT_DIR=${2:?}; shift 2;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2;;
    esac
done
[[ -f $GPU_VPU_IMAGE && -f $NPU_IMAGE && -n $OUTPUT_DIR ]] || { echo 'ERROR: image arguments missing' >&2; exit 2; }
apt-get update >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    e2fsprogs gzip mount p7zip-full tar util-linux xz-utils >/dev/null
WORK=$(mktemp -d -p /tmp zero3w-image.XXXXXXXX)
trap 'umount -l "$WORK/radxa" 2>/dev/null || true; umount -l "$WORK/orangepi" 2>/dev/null || true; losetup -D 2>/dev/null || true; rm -rf "$WORK"' EXIT
mkdir -p "$WORK/radxa" "$WORK/orangepi"
prepare_image() {
    local input=$1 name=$2 image loop partition start sectors candidate
    image=$input
    case "$input" in
        *.xz) image="$WORK/$name.img"; xz -dc -- "$input" > "$image";;
        *.7z) 7z x -so -- "$input" '*.img' > "$WORK/$name.img"; image="$WORK/$name.img";;
    esac
    if [[ $(blkid -o value -s TYPE "$image" 2>/dev/null || true) == ext4 ]]; then
        loop=$(losetup --find --show "$image")
        mount -o ro "$loop" "$WORK/$name"
        return
    fi
    while read -r start sectors; do
        [[ $start =~ ^[0-9]+$ && $sectors =~ ^[0-9]+$ ]] || continue
        if [[ $(blkid -p -o value -s TYPE -O $((start * 512)) "$image" 2>/dev/null || true) == ext4 ]]; then
            candidate=$(losetup --find --show -o $((start * 512)) --sizelimit $((sectors * 512)) "$image")
            mount -o ro "$candidate" "$WORK/$name"
            return
        fi
    done < <(partx -g -o START,SECTORS -r "$image")
    echo "ERROR: no ext4 root filesystem in $input" >&2
    exit 1
}
prepare_image "$GPU_VPU_IMAGE" radxa
prepare_image "$NPU_IMAGE" orangepi
mkdir -p "$OUTPUT_DIR"
exec /work/scripts/extract-vendor-userspace.sh --gpu-vpu-root "$WORK/radxa" \
    --npu-root "$WORK/orangepi" --output-dir "$OUTPUT_DIR"
