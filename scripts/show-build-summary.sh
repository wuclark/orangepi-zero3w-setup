#!/usr/bin/env bash
# Purpose: Inspect credential-bearing files embedded in an image and print a redacted build summary.
# Platform: Host workstation with loop/mount tools and sudo permission for read-only image inspection.
# Inputs: Final image, optional preset/provisioning paths, and optional --unredacted.
# Dependencies: Bash, losetup, mount, partx, blkid, sudo, and a readable image filesystem.
# Writes: Temporary read-only mount state under /tmp; no repository or image contents are modified.
# Safety: Redacts credentials by default; --unredacted is for local troubleshooting only.
# Repeat: Recreates temporary inspection mounts and removes them through the cleanup trap.
# Recovery: Cleanup is automatic; detach any stale loop/mount resources only after validating exact targets.
# Outputs: Image metadata, embedded file summary, and optional unredacted local values.
# Verification: Confirm the final image contains the intended preset/provisioning paths without exposing secrets.
# Documentation: docs/development/development.md
set -Eeuo pipefail
UNREDACTED=no
POSITIONAL=()
while (($#)); do
    case "$1" in
        --unredacted) UNREDACTED=yes; shift ;;
        --) shift; POSITIONAL+=("$@"); break ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done
IMAGE=${POSITIONAL[0]:?Usage: $0 [--unredacted] FINAL_IMAGE [PRESET] [PROVISIONING]}
PRESET=${POSITIONAL[1]:-not_logged_in_yet}
PROVISIONING=${POSITIONAL[2]:-provisioning.sh}
REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ -f $IMAGE ]] || { echo "ERROR: image not found: $IMAGE" >&2; exit 1; }
[[ -f $PRESET ]] || { echo "ERROR: preset not found: $PRESET" >&2; exit 1; }
[[ -f $PROVISIONING ]] || { echo "ERROR: provisioning hook not found: $PROVISIONING" >&2; exit 1; }

for tool in losetup mount umount partx blkid sudo; do
    command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: $tool is required to verify embedded files" >&2; exit 1; }
done

value_from_preset() {
    local key=$1
    sed -n "s/^${key}=\"\(.*\)\"$/\1/p" "$PRESET" | head -n 1
}

read_image_file() {
    local image=$1 path=$2 work loop found=""
    work=$(mktemp -d -p /tmp zero3w-summary.XXXXXXXX)
    trap 'sudo umount -l "$work" 2>/dev/null || true; sudo losetup -D 2>/dev/null || true; rm -rf "$work"' RETURN
    while read -r start sectors; do
        [[ $start =~ ^[0-9]+$ && $sectors =~ ^[0-9]+$ ]] || continue
        if [[ $(blkid -p -o value -s TYPE -O $((start * 512)) "$image" 2>/dev/null || true) == ext4 ]]; then
            loop=$(sudo losetup --find --show -o $((start * 512)) --sizelimit $((sectors * 512)) "$image") || continue
            if sudo mount -o ro "$loop" "$work" 2>/dev/null; then found=1; break; fi
            sudo losetup -d "$loop" 2>/dev/null || true
        fi
    done < <(partx -g -o START,SECTORS -r "$image")
    [[ -n $found ]] || { echo "ERROR: could not mount $image root filesystem to verify embedded files" >&2; return 1; }
    [[ -e $work$path ]] || { echo "ERROR: $path not found in $image" >&2; return 1; }
    sudo cat -- "$work$path"
}
hostname_value=$(sed -n -E \
    -e "s/.*hostnamectl set-hostname \"([^\"]+)\".*/\1/p" \
    -e "s/.*hostnamectl set-hostname '([^']+)'.*/\1/p" "$PROVISIONING" | head -n 1)
hostname_value=${hostname_value:-not found}
username=$(value_from_preset PRESET_USER_NAME)
ssid=$(value_from_preset PRESET_NET_WIFI_SSID)
root_password=$(value_from_preset PRESET_ROOT_PASSWORD)
user_password=$(value_from_preset PRESET_USER_PASSWORD)
wifi_password=$(value_from_preset PRESET_NET_WIFI_KEY)

redacted_value() {
    if [[ -n $1 ]]; then printf '%s' 'SET (redacted)'; else printf '%s' 'NOT SET'; fi
}

printf '%s\n' '===== Orange Pi SD image build summary ====='
printf 'built_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'final_image=%s\n' "$(realpath "$IMAGE")"
printf 'image_name=%s\n' "$(basename "$IMAGE")"
printf 'image_size=%s\n' "$(du -h "$IMAGE" | awk '{print $1}')"
printf 'checksum_file=%s\n' "$(realpath "$IMAGE.sha256" 2>/dev/null || printf '%s' "$IMAGE.sha256")"
printf 'final_sha256=%s\n' "$(sha256sum "$IMAGE" | awk '{print $1}')"
for archive in pvr-userspace.tar.gz vpu-userspace.tar.gz npu-userspace.tar.gz; do
    archive_path="$REPO_ROOT/work/vendor-output/$archive"
    if [[ -f $archive_path ]]; then
        printf 'archive_%s_sha256=%s\n' "${archive%.tar.gz}" "$(sha256sum "$archive_path" | awk '{print $1}')"
    fi
done
printf 'embedded_repository=/opt/orangepi-zero3w-setup\n'
printf 'hostname=%s\n' "$hostname_value"
printf 'username=%s\n' "${username:-not found}"
printf 'wifi_ssid=%s\n' "${ssid:-not found}"
if [[ $UNREDACTED == yes ]]; then
    printf 'root_password=%s\n' "${root_password:-NOT SET}"
    printf 'user_password=%s\n' "${user_password:-NOT SET}"
    printf 'wifi_password=%s\n' "${wifi_password:-NOT SET}"
else
    printf 'root_password=%s\n' "$(redacted_value "$root_password")"
    printf 'user_password=%s\n' "$(redacted_value "$user_password")"
    printf 'wifi_password=%s\n' "$(redacted_value "$wifi_password")"
fi
printf '%s\n' 'next_step=validate the exact image path, then write it to the confirmed SD-card device'
printf '%s\n' 'warning=writing an image overwrites the selected device; verify the device independently'
embedded_preset=$(read_image_file "$IMAGE" /root/.not_logged_in_yet) || exit 1
embedded_provisioning=$(read_image_file "$IMAGE" /root/provisioning.sh) || exit 1
if [[ $UNREDACTED == yes ]]; then
    printf '%s\n' '----- /root/.not_logged_in_yet (read from mounted final image) -----'
    printf '%s\n' "$embedded_preset"
    printf '%s\n' '---------------------------------------------------------------------------'
    printf '%s\n' '----- /root/provisioning.sh (read from mounted final image) -----'
    printf '%s\n' "$embedded_provisioning"
    printf '%s\n' '---------------------------------------------------------------------------------'
else
    printf '%s\n' 'embedded_preset=present (redacted)'
    printf '%s\n' 'embedded_provisioning=present (redacted)'
fi
if ! diff -q <(printf '%s\n' "$embedded_preset") "$PRESET" >/dev/null; then
    printf '%s\n' 'WARNING: embedded /root/.not_logged_in_yet differs from local not_logged_in_yet'
fi
if ! diff -q <(printf '%s\n' "$embedded_provisioning") "$PROVISIONING" >/dev/null; then
    printf '%s\n' 'WARNING: embedded /root/provisioning.sh differs from local provisioning.sh'
fi
printf '%s\n' '============================================='
