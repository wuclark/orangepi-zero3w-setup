#!/usr/bin/env bash
set -Eeuo pipefail
BASE_IMAGE=""; BASE_FORMAT=""; OUTPUT_IMAGE=""
while (($#)); do
    case "$1" in
        --base-image) BASE_IMAGE=${2:?}; shift 2;;
        --base-format) BASE_FORMAT=${2:?}; shift 2;;
        --output-image) OUTPUT_IMAGE=${2:?}; shift 2;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2;;
    esac
done
[[ -f $BASE_IMAGE && -n $BASE_FORMAT && -n $OUTPUT_IMAGE ]] || { echo 'ERROR: image arguments missing' >&2; exit 2; }
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends e2fsprogs gzip mount tar util-linux xz-utils >/dev/null
case "$BASE_FORMAT" in
    xz) xz -dc -- "$BASE_IMAGE" > "$OUTPUT_IMAGE";;
    7z) apt-get install -y -qq --no-install-recommends p7zip-full >/dev/null; 7z x -so -- "$BASE_IMAGE" '*.img' > "$OUTPUT_IMAGE";;
    *) cp -- "$BASE_IMAGE" "$OUTPUT_IMAGE";;
esac
WORK=$(mktemp -d -p /tmp zero3w-preload.XXXXXXXX)
trap 'umount -l "$WORK/root" 2>/dev/null || true; losetup -D 2>/dev/null || true; rm -rf "$WORK"' EXIT
mkdir -p "$WORK/root"
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
tar -C /repo --exclude=.git --exclude=work --exclude=vendor-files -cf - . | tar -C "$TARGET" -xf -
cp -a /repo/work/vendor-output/pvr-userspace.tar.gz "$TARGET/vendor-files/"
for archive in vpu-userspace.tar.gz npu-userspace.tar.gz; do
    [[ -f /repo/work/vendor-output/$archive ]] && cp -a "/repo/work/vendor-output/$archive" "$TARGET/vendor-files/"
done
chown -R root:root "$TARGET"; chmod 0644 "$TARGET/vendor-files/"*.tar.gz
find "$TARGET" -type d -exec chmod 755 {} +
find "$TARGET" -type f -printf '%P\n' | sort > "$OUTPUT_IMAGE.manifest.txt"
sync; umount "$WORK/root"; losetup -D 2>/dev/null || true
(cd "$(dirname "$OUTPUT_IMAGE")" && sha256sum "$(basename "$OUTPUT_IMAGE")" > "$(basename "$OUTPUT_IMAGE").sha256")
printf 'preloaded image created: %s\n' "$OUTPUT_IMAGE"
