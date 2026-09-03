#!/usr/bin/env bash
# Purpose: Copy the repository and staged vendor archives into an image root.
# Platform: privileged Linux container with loop, partition, and mount utilities.
# Inputs: base image/format and output image; repository is supplied at /repo.
# Writes: output image root filesystem, excluding Git and generated video fixtures.
# Safety: uses temporary mounts and cleanup traps; never extracts an archive over /.
# Repeat behavior: creates a separate derived image and refuses no explicit overwrite.
# Recovery: cleanup releases temporary mounts/loops; discard a failed partial output.
# Verification: validate the image and confirm archive hashes before SD deployment.
set -Eeuo pipefail
BASE_IMAGE=""; BASE_FORMAT=""; OUTPUT_IMAGE=""
progress() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
while (($#)); do
    case "$1" in
        --base-image) BASE_IMAGE=${2:?}; shift 2;;
        --base-format) BASE_FORMAT=${2:?}; shift 2;;
        --output-image) OUTPUT_IMAGE=${2:?}; shift 2;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2;;
    esac
done
[[ -f $BASE_IMAGE && -n $BASE_FORMAT && -n $OUTPUT_IMAGE ]] || { echo 'ERROR: image arguments missing' >&2; exit 2; }
case "$BASE_FORMAT" in
    xz) progress 'Decompressing base image'; xz -dc -- "$BASE_IMAGE" > "$OUTPUT_IMAGE";;
    7z) progress 'Extracting base image'; 7z x -so -- "$BASE_IMAGE" '*.img' > "$OUTPUT_IMAGE";;
    *) progress 'Copying base image'; cp -- "$BASE_IMAGE" "$OUTPUT_IMAGE";;
esac
WORK=$(mktemp -d -p /tmp zero3w-preload.XXXXXXXX)
trap 'umount -l "$WORK/root" 2>/dev/null || true; losetup -D 2>/dev/null || true; rm -rf "$WORK"' EXIT
mkdir -p "$WORK/root"
progress 'Mounting output image root filesystem'
start=0; sectors=0; loop=""
while read -r start sectors; do
    [[ $start =~ ^[0-9]+$ && $sectors =~ ^[0-9]+$ ]] || continue
    if [[ $(blkid -p -o value -s TYPE -O $((start * 512)) "$OUTPUT_IMAGE" 2>/dev/null || true) == ext4 ]]; then
        loop=$(losetup --find --show -o $((start * 512)) --sizelimit $((sectors * 512)) "$OUTPUT_IMAGE")
        mount "$loop" "$WORK/root"
        break
    fi
done < <(partx -g -o START,SECTORS -r "$OUTPUT_IMAGE")
[[ -n $loop ]] || { echo 'ERROR: no ext4 root partition found' >&2; exit 1; }
TARGET="$WORK/root/opt/orangepi-zero3w-setup"
install -d -m 755 "$TARGET/vendor-files"
chmod 755 "$(dirname "$TARGET")"
progress 'Copying repository into the image'
# Generated VPU fixtures are intentionally kept outside Git and can consume
# more space than the base image's root filesystem has available. The board
# test downloads or generates them on demand after installation.
tar -C /repo \
    --exclude=.git --exclude=work --exclude=vendor-files \
    --exclude='testdata/videos/*.mp4' \
    --exclude='testdata/videos/*.md5' \
    --exclude='testdata/videos/SHA256SUMS' \
    -cf - . | tar -C "$TARGET" -xf -
decode_fixture_dir="$TARGET/testdata/videos"
for fixture in \
    mandelbrot-h264-720p-30fps.mp4 mandelbrot-h264-720p-30fps.md5 \
    mandelbrot-h265-720p-30fps.mp4 mandelbrot-h265-720p-30fps.md5
do
    if [[ -s "/repo/testdata/videos/$fixture" ]]; then
        install -d -m 755 "$decode_fixture_dir"
        cp -a "/repo/testdata/videos/$fixture" "$decode_fixture_dir/"
    fi
done
progress 'Copying vendor userspace archives into the image'
cp -a /repo/work/vendor-output/pvr-userspace.tar.gz "$TARGET/vendor-files/"
for archive in vpu-userspace.tar.gz npu-userspace.tar.gz; do
    [[ -f /repo/work/vendor-output/$archive ]] && cp -a "/repo/work/vendor-output/$archive" "$TARGET/vendor-files/"
done
[[ -f /repo/work/vendor-output/npu-test-assets.tar.gz ]] && \
    cp -a /repo/work/vendor-output/npu-test-assets.tar.gz "$TARGET/vendor-files/"
# NPU golden archives are optional and only exist once generated on the
# host (make npu-golden-candidate / npu-golden-lenet / -yolov5 / -resnet50).
# Bake in whichever ones are present so a fresh SD card already carries
# them; see docs/optional/npu.md for how each is produced and verified.
for golden_archive in npu-golden-candidate npu-golden-lenet npu-golden-yolov5 npu-golden-resnet50; do
    [[ -f /repo/work/vendor-output/$golden_archive.tar.gz ]] && \
        cp -a "/repo/work/vendor-output/$golden_archive.tar.gz" "$TARGET/vendor-files/"
done
chown -R root:root "$TARGET"; chmod 0644 "$TARGET/vendor-files/"*.tar.gz
find "$TARGET" -type d -exec chmod 755 {} +
find "$TARGET" -type f -printf '%P\n' | sort > "$OUTPUT_IMAGE.manifest.txt"
progress 'Unmounting output image and computing checksum'
sync; umount "$WORK/root"; losetup -D 2>/dev/null || true
(cd "$(dirname "$OUTPUT_IMAGE")" && sha256sum "$(basename "$OUTPUT_IMAGE")" > "$(basename "$OUTPUT_IMAGE").sha256")
progress "preloaded image created: $OUTPUT_IMAGE"
