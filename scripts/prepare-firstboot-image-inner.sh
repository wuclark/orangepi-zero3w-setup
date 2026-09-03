#!/usr/bin/env bash
# Purpose: Prepare a mounted image inside the pinned Docker userspace container.
# Platform: privileged Linux container with loop, partition, and mount utilities.
# Inputs: base image/format, first-boot preset, provisioning hook, output image.
# Writes: output image root filesystem and first-boot files; temporary mounts are used.
# Safety: validates arguments, mounts the root partition, and cleans up on exit.
# Repeat behavior: produces a new output and must not overwrite an existing image.
# Recovery: cleanup trap releases temporary mounts/loops; discard partial output safely.
# Verification: validate the resulting image before SD-card deployment.
set -Eeuo pipefail
BASE_IMAGE=""; BASE_FORMAT=""; PRESET=""; PROVISIONING=""; OUTPUT_IMAGE=""
progress() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
while (($#)); do
    case "$1" in
        --base-image) BASE_IMAGE=${2:?}; shift 2;;
        --base-format) BASE_FORMAT=${2:?}; shift 2;;
        --preset) PRESET=${2:?}; shift 2;;
        --provisioning) PROVISIONING=${2:?}; shift 2;;
        --output-image) OUTPUT_IMAGE=${2:?}; shift 2;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2;;
    esac
done
[[ -f $BASE_IMAGE && -f $PRESET && -f $PROVISIONING && -n $BASE_FORMAT && -n $OUTPUT_IMAGE ]] || {
    echo 'ERROR: image, first-boot files, or output arguments missing' >&2; exit 2;
}
case "$BASE_FORMAT" in
    xz) progress 'Decompressing base image'; xz -dc -- "$BASE_IMAGE" > "$OUTPUT_IMAGE";;
    7z) progress 'Extracting base image'; 7z x -so -- "$BASE_IMAGE" '*.img' > "$OUTPUT_IMAGE";;
    *) progress 'Copying base image'; cp -- "$BASE_IMAGE" "$OUTPUT_IMAGE";;
esac
WORK=$(mktemp -d -p /tmp zero3w-firstboot.XXXXXXXX)
trap 'umount -l "$WORK/root" 2>/dev/null || true; losetup -D 2>/dev/null || true; rm -rf "$WORK"' EXIT
mkdir -p "$WORK/root"
progress 'Mounting output image root filesystem'
loop=""
while read -r start sectors; do
    [[ $start =~ ^[0-9]+$ && $sectors =~ ^[0-9]+$ ]] || continue
    if [[ $(blkid -p -o value -s TYPE -O $((start * 512)) "$OUTPUT_IMAGE" 2>/dev/null || true) == ext4 ]]; then
        loop=$(losetup --find --show -o $((start * 512)) --sizelimit $((sectors * 512)) "$OUTPUT_IMAGE")
        mount "$loop" "$WORK/root"
        break
    fi
done < <(partx -g -o START,SECTORS -r "$OUTPUT_IMAGE")
[[ -n $loop ]] || { echo 'ERROR: no ext4 root partition found' >&2; exit 1; }
user_name=$(sed -n 's/^PRESET_USER_NAME="\([a-z_][a-z0-9_-]*\)\$\?"$/\1/p' "$PRESET")
[[ $user_name =~ ^[a-z_][a-z0-9_-]*\$?$ ]] || {
    echo 'ERROR: preset must contain a valid PRESET_USER_NAME' >&2; exit 1;
}
progress 'Installing first-boot preset and provisioning hook'
install -d -m 755 "$WORK/root/root"
install -o root -g root -m 600 "$PRESET" "$WORK/root/root/.not_logged_in_yet"
{
    cat "$PROVISIONING"
    printf '\n# Link the preloaded repository into the selected first-boot user home.\n'
    printf 'install -d -m 755 -o %q -g %q /home/%q\n' "$user_name" "$user_name" "$user_name"
    printf 'ln -sfn /opt/orangepi-zero3w-setup /home/%q/orangepi-zero3w-setup\n' "$user_name"
} > "$WORK/provisioning.sh"
install -o root -g root -m 700 "$WORK/provisioning.sh" "$WORK/root/root/provisioning.sh"
progress 'Unmounting output image and computing checksum'
sync; umount "$WORK/root"; losetup -D 2>/dev/null || true
(cd "$(dirname "$OUTPUT_IMAGE")" && sha256sum "$(basename "$OUTPUT_IMAGE")" > "$(basename "$OUTPUT_IMAGE").sha256")
progress "first-boot image created: $OUTPUT_IMAGE"
