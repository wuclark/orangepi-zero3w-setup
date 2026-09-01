#!/usr/bin/env bash
set -Eeuo pipefail
IMAGE=${1:?Usage: $0 FINAL_IMAGE [PRESET] [PROVISIONING]}
PRESET=${2:-not_logged_in_yet}
PROVISIONING=${3:-provisioning.sh}
REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ -f $IMAGE ]] || { echo "ERROR: image not found: $IMAGE" >&2; exit 1; }
[[ -f $PRESET ]] || { echo "ERROR: preset not found: $PRESET" >&2; exit 1; }
[[ -f $PROVISIONING ]] || { echo "ERROR: provisioning hook not found: $PROVISIONING" >&2; exit 1; }

value_from_preset() {
    local key=$1
    sed -n "s/^${key}=\"\(.*\)\"$/\1/p" "$PRESET" | head -n 1
}
set_from_preset() {
    local key=$1 value
    value=$(value_from_preset "$key")
    [[ -n $value ]]
}
hostname_value=$(sed -n -E \
    -e "s/.*hostnamectl set-hostname \"([^\"]+)\".*/\1/p" \
    -e "s/.*hostnamectl set-hostname '([^']+)'.*/\1/p" "$PROVISIONING" | head -n 1)
hostname_value=${hostname_value:-not found}
username=$(value_from_preset PRESET_USER_NAME)
ssid=$(value_from_preset PRESET_NET_WIFI_SSID)

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
if set_from_preset PRESET_ROOT_PASSWORD; then printf '%s\n' 'root_password=SET (*****)'; else printf '%s\n' 'root_password=NOT SET'; fi
if set_from_preset PRESET_USER_PASSWORD; then printf '%s\n' 'user_password=SET (*****)'; else printf '%s\n' 'user_password=NOT SET'; fi
if set_from_preset PRESET_NET_WIFI_KEY; then printf '%s\n' 'wifi_password=SET (*****)'; else printf '%s\n' 'wifi_password=NOT SET'; fi
printf '%s\n' 'next_step=validate the exact image path, then write it to the confirmed SD-card device'
printf '%s\n' 'warning=writing an image overwrites the selected device; verify the device independently'
printf '%s\n' '============================================='
