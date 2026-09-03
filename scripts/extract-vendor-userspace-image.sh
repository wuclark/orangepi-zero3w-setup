#!/usr/bin/env bash
# Purpose: Extract vendor userspace directly from two local disk images.
# Platform: native Linux/WSL2 with root, loop, mount, and image inspection tools.
# Inputs: --gpu-vpu-image, --npu-image, and --output-dir.
# Writes: private generated archives and manifests in the requested output directory.
# Safety: source filesystems are mounted read-only and temporary resources are trapped.
# Repeat behavior: output must be selected deliberately; existing output is validated.
# Recovery: cleanup runs on exit; inspect logs and remove only failed private output.
# Verification: run tests/test-archives.sh and compare manifests with source images.
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
progress() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
WORK=$(mktemp -d -p /tmp zero3w-image.XXXXXXXX)
cleanup() {
    progress 'Unmounting temporary source filesystems'
    umount -l "$WORK/radxa" 2>/dev/null || true
    umount -l "$WORK/orangepi" 2>/dev/null || true
    progress 'Releasing temporary loop devices'
    losetup -D 2>/dev/null || true
    progress 'Removing temporary extraction workspace'
    rm -rf "$WORK"
    progress 'Temporary extraction cleanup complete'
}
trap cleanup EXIT
mkdir -p "$WORK/radxa" "$WORK/orangepi"
prepare_image() {
    local input=$1 name=$2 image loop partition start sectors candidate
    image=$input
    case "$input" in
        *.xz) progress "Decompressing $name source image"; image="$WORK/$name.img"; xz -dc -- "$input" > "$image";;
        *.7z)  progress "Extracting $name source image"; 7z x -so -- "$input" '*.img' > "$WORK/$name.img"; image="$WORK/$name.img";;
    esac
    progress "Mounting $name root filesystem read-only"
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
progress 'Preparing GPU/VPU source image'
prepare_image "$GPU_VPU_IMAGE" radxa
progress 'Preparing NPU source image'
prepare_image "$NPU_IMAGE" orangepi
mkdir -p "$OUTPUT_DIR"
progress 'Scanning source files and creating userspace archives'
exec /work/scripts/extract-vendor-userspace.sh --gpu-vpu-root "$WORK/radxa" \
    --npu-root "$WORK/orangepi" --output-dir "$OUTPUT_DIR"
