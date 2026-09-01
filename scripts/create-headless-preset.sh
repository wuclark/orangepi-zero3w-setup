#!/usr/bin/env bash
set -Eeuo pipefail

# Create Armbian's first-boot preset without placing credentials in the repo.
# Use --root-mount to write directly to a mounted Armbian root filesystem, or
# --output to create the file for later copying to /root/.not_logged_in_yet.
OUTPUT=
ROOT_MOUNT=
USER_NAME=orangepi

usage() {
    cat <<EOF
Usage: $0 [--root-mount DIR | --output FILE]

Prompts for the user, passwords, and Wi-Fi credentials. Passwords
are written in plaintext because Armbian requires that for automatic first
boot. Delete the generated file after the board has booted.
EOF
}
while (($#)); do
    case "$1" in
        --root-mount) ROOT_MOUNT=${2:?missing mount directory}; shift 2 ;;
        --output) OUTPUT=${2:?missing output file}; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done
[[ -n $ROOT_MOUNT || -n $OUTPUT ]] || { usage >&2; exit 2; }
[[ -z $ROOT_MOUNT || -z $OUTPUT ]] || { echo 'Use only one output option.' >&2; exit 2; }
read -r -p 'Username [orangepi]: ' answer; USER_NAME=${answer:-$USER_NAME}
read -r -s -p 'Root password: ' ROOT_PASSWORD; printf '\n'
read -r -s -p 'User password: ' USER_PASSWORD; printf '\n'
read -r -p 'Wi-Fi SSID: ' WIFI_SSID
read -r -s -p 'Wi-Fi password: ' WIFI_PASSWORD; printf '\n'
[[ $USER_NAME =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || { echo 'Invalid username.' >&2; exit 1; }
[[ -n $WIFI_SSID && -n $WIFI_PASSWORD ]] || { echo 'Wi-Fi values cannot be empty.' >&2; exit 1; }
escape_config() {
    printf '%s' "$1" | sed 's/[\\"$`]/\\&/g'
}
USER_NAME=$(escape_config "$USER_NAME")
ROOT_PASSWORD=$(escape_config "$ROOT_PASSWORD")
USER_PASSWORD=$(escape_config "$USER_PASSWORD")
WIFI_SSID=$(escape_config "$WIFI_SSID")
WIFI_PASSWORD=$(escape_config "$WIFI_PASSWORD")
if [[ -n $ROOT_MOUNT ]]; then
    [[ -d $ROOT_MOUNT/etc ]] || { echo "Not an Armbian root mount: $ROOT_MOUNT" >&2; exit 1; }
    OUTPUT=$ROOT_MOUNT/root/.not_logged_in_yet
fi
install -d -m 700 "$(dirname -- "$OUTPUT")"
umask 077
cat > "$OUTPUT" <<EOF
PRESET_NET_CHANGE_DEFAULTS="1"
PRESET_NET_WIFI_ENABLED="1"
PRESET_NET_WIFI_SSID="$WIFI_SSID"
PRESET_NET_WIFI_KEY="$WIFI_PASSWORD"
PRESET_NET_WIFI_COUNTRYCODE="US"
PRESET_CONNECT_WIRELESS="n"
PRESET_NET_USE_STATIC="0"
PRESET_ROOT_PASSWORD="$ROOT_PASSWORD"
PRESET_USER_NAME="$USER_NAME"
PRESET_USER_PASSWORD="$USER_PASSWORD"
PRESET_DEFAULT_REALNAME="$USER_NAME"
PRESET_USER_SHELL="bash"
SET_LANG_BASED_ON_LOCATION="n"
PRESET_LOCALE="en_US.UTF-8"
PRESET_TIMEZONE="America/Los_Angeles"
EOF
chmod 600 "$OUTPUT"
printf 'Created %s (mode 600). Delete it after first boot.\n' "$OUTPUT"
