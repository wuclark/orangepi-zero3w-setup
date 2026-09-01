#!/usr/bin/env bash
set -Eeuo pipefail
BASE_IMAGE=""; BASE_FORMAT=""; PRESET=""; PROVISIONING=""; OUTPUT_IMAGE=""
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
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    e2fsprogs gzip mount tar util-linux xz-utils >/dev/null
case "$BASE_FORMAT" in
    xz) xz -dc -- "$BASE_IMAGE" > "$OUTPUT_IMAGE";;
    7z) apt-get install -y -qq --no-install-recommends p7zip-full >/dev/null; 7z x -so -- "$BASE_IMAGE" '*.img' > "$OUTPUT_IMAGE";;
    *) cp -- "$BASE_IMAGE" "$OUTPUT_IMAGE";;
esac
WORK=$(mktemp -d -p /tmp zero3w-firstboot.XXXXXXXX)
trap 'umount -l "$WORK/root" 2>/dev/null || true; losetup -D 2>/dev/null || true; rm -rf "$WORK"' EXIT
mkdir -p "$WORK/root"
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
install -d -m 755 "$WORK/root/root"
install -o root -g root -m 600 "$PRESET" "$WORK/root/root/.not_logged_in_yet"
{
    cat "$PROVISIONING"
    printf '\n# Link the preloaded repository into the selected first-boot user home.\n'
    printf 'install -d -m 755 -o %q -g %q /home/%q\n' "$user_name" "$user_name" "$user_name"
    printf 'ln -sfn /opt/orangepi-zero3w-setup /home/%q/orangepi-zero3w-setup\n' "$user_name"
} > "$WORK/provisioning.sh"
install -o root -g root -m 700 "$WORK/provisioning.sh" "$WORK/root/root/provisioning.sh"
sync; umount "$WORK/root"; losetup -D 2>/dev/null || true
(cd "$(dirname "$OUTPUT_IMAGE")" && sha256sum "$(basename "$OUTPUT_IMAGE")" > "$(basename "$OUTPUT_IMAGE").sha256")
printf 'first-boot image created: %s\n' "$OUTPUT_IMAGE"
