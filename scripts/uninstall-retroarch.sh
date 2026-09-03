#!/usr/bin/env bash
# Purpose: Remove only packages and files tracked by the RetroArch feature.
# Platform: Debian/Armbian board; operates on a selected non-root desktop user.
# Inputs: optional RETROARCH_USER; interactive confirmation is always required.
# Writes: removes tracked packages, launcher, desktop entry, and feature state.
# Safety: preserves ROMs, saves, and user configuration unless separately chosen.
# Repeat behavior: cancellation is safe; already-removed tracked items are skipped.
# Recovery: reinstall the feature or restore the timestamped RetroArch config backup.
# Verification: run board-status and board-retroarch-verify after reinstalling.
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root
TARGET_USER=${RETROARCH_USER:-$(resolve_real_user)}
[[ $TARGET_USER != root ]] || die 'Refusing to operate on /root; specify RETROARCH_USER.'
id "$TARGET_USER" >/dev/null 2>&1 || die "User does not exist: $TARGET_USER"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
read -r -p "Remove the RetroArch feature for $TARGET_USER? [y/N] " answer
[[ $answer =~ ^[Yy]$ ]] || { echo 'Cancelled.'; exit 0; }

if [[ -f /etc/orangepi-zero3w-setup/state/retroarch-packages ]]; then
    mapfile -t packages < <(sed '/^[[:space:]]*$/d' /etc/orangepi-zero3w-setup/state/retroarch-packages)
    if ((${#packages[@]})); then
        printf 'Removing packages tracked as installed by this feature:\n  %s\n' "${packages[*]}"
        apt-get remove -y "${packages[@]}"
    fi
    rm -f /etc/orangepi-zero3w-setup/state/retroarch-packages
else
    echo 'No package ownership record found; leaving packages installed.'
fi
rm -f /usr/local/bin/retroarch-powervr /usr/share/applications/retroarch-powervr.desktop
if [[ -f /etc/orangepi-zero3w-setup/state/retroarch-core-files ]]; then
    while IFS= read -r core_file; do
        [[ -n $core_file && $core_file == /usr/lib/aarch64-linux-gnu/libretro/*.so ]] && rm -f -- "$core_file"
    done < /etc/orangepi-zero3w-setup/state/retroarch-core-files
    rm -f /etc/orangepi-zero3w-setup/state/retroarch-core-files
fi
read -r -p 'Remove RetroArch configuration, ROMs, and saves? They are preserved by default. [y/N] ' remove_data
if [[ $remove_data =~ ^[Yy]$ ]]; then
    for path in "$USER_HOME/.config/retroarch" "$USER_HOME/.local/share/retroarch" "$USER_HOME/RetroArch/roms" "$USER_HOME/RetroArch/saves" "$USER_HOME/roms"; do
        if [[ -e $path ]]; then
            rm -rf -- "$path"
            log "Removed explicitly selected path: $path"
        fi
    done
else
    echo 'ROMs, saves, and configuration were preserved.'
fi
echo 'RetroArch launcher and desktop entry removed. Existing group memberships were preserved.'
