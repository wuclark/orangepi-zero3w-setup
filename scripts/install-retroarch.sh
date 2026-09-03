#!/usr/bin/env bash
# Purpose: Install/configure Debian RetroArch with isolated PowerVR Vulkan and ALSA.
# Platform: arm64 Orange Pi Zero 3W, X11 display :0, DDK under /opt/pvr-ddk-24.2.
# Inputs: install/repair/core/download/audio options and RETROARCH_* environment.
# Writes: packages, user config, launcher/desktop entry, state, and config backups.
# Safety: never exports the PVR directory globally as LD_LIBRARY_PATH.
# Repeat behavior: idempotently replaces managed keys and tracks newly installed packages.
# Recovery: --repair restores the newest config backup; uninstall preserves ROMs by default.
# Verification: board-retroarch-verify and board-retroarch-core-check on the board.
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

TARGET_USER=${RETROARCH_USER:-}
UPDATE=no
REPAIR=no
EMULATIONSTATION=no
ADVANCED_CORES=no
DOWNLOAD_ADVANCED=no
AUTO_AUDIO=no
AUDIO_DEVICE=${RETROARCH_AUDIO_DEVICE:-default}
CORE_FILES=${RETROARCH_CORE_FILES:-}
CORE_CACHE_DIR=${RETROARCH_CORE_CACHE_DIR:-/var/cache/orangepi-zero3w-setup/retroarch-cores}
LOG_FILE=/var/log/orangepi-zero3w-setup/retroarch-install.log

usage() {
    cat <<'EOF'
Usage: sudo ./scripts/install-retroarch.sh [options]

Options:
  --install                 Install/configure RetroArch (default)
  --repair                  Repair the existing RetroArch configuration
  --user USER               Configure this non-root desktop user
  --audio-device DEVICE     ALSA device (default: default)
  --emulationstation       Install EmulationStation when available
  --advanced-cores         Install available advanced cores or supplied ARM64 .so files
  --download-advanced      Download five official Libretro aarch64 cores
  --audio-auto             Select ALSA default, then explicit HDMI plughw
  --core-file FILE         Install a user-supplied ARM64 Libretro .so core
  --update                  Explicitly refresh apt metadata
  -h, --help                Show this help

The PowerVR Vulkan environment is isolated in /usr/local/bin/retroarch-powervr.
No global LD_LIBRARY_PATH is configured.
EOF
}

while (($#)); do
    case "$1" in
        --install) shift;;
        --repair) REPAIR=yes; shift;;
        --user) TARGET_USER=${2:?missing user}; shift 2;;
        --audio-device) AUDIO_DEVICE=${2:?missing device}; shift 2;;
        --emulationstation) EMULATIONSTATION=yes; shift;;
        --advanced-cores) ADVANCED_CORES=yes; shift;;
        --download-advanced) ADVANCED_CORES=yes; DOWNLOAD_ADVANCED=yes; shift;;
        --audio-auto) AUTO_AUDIO=yes; shift;;
        --core-file) ADVANCED_CORES=yes; CORE_FILES+=" ${2:?missing core file}"; shift 2;;
        --update) UPDATE=yes; shift;;
        -h|--help) usage; exit 0;;
        *) die "Unknown argument: $1";;
    esac
done

install -d -m 755 /var/log/orangepi-zero3w-setup
exec > >(tee -a "$LOG_FILE") 2>&1

ARCH=$(uname -m)
[[ $ARCH == aarch64 || $ARCH == arm64 ]] || die "RetroArch PowerVR setup requires arm64/aarch64; found $ARCH."
[[ -f $PVR_ROOT/vulkan/img_icd.json ]] || die "Missing PowerVR Vulkan ICD: $PVR_ROOT/vulkan/img_icd.json"
[[ -d /dev/dri ]] || die 'Missing /dev/dri; install the board GPU layer first.'
lsmod | grep -q '^pvrsrvkm ' || die 'pvrsrvkm is not loaded; run the GPU setup and reboot before RetroArch setup.'

if [[ -z $TARGET_USER ]]; then
    if [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]]; then
        TARGET_USER=$SUDO_USER
    elif [[ -f /etc/orangepi-zero3w-setup/state/user ]]; then
        TARGET_USER=$(head -n1 /etc/orangepi-zero3w-setup/state/user)
    else
        TARGET_USER=orangepi
    fi
fi
[[ $TARGET_USER != root ]] || die 'Refusing to configure RetroArch under /root; specify --user USER.'
id "$TARGET_USER" >/dev/null 2>&1 || die "User does not exist: $TARGET_USER"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
USER_GROUP=$(id -gn "$TARGET_USER")
[[ -n $USER_HOME ]] || die "Cannot determine home directory for $TARGET_USER"

for group in video render audio input games; do
    getent group "$group" >/dev/null 2>&1 || groupadd --system "$group"
    if ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx "$group"; then
        usermod -aG "$group" "$TARGET_USER"
        log "Added $TARGET_USER to $group; logout/login or reboot is required for the new membership."
    fi
done

packages=(retroarch retroarch-assets libretro-core-info)
if ! command -v vulkaninfo >/dev/null 2>&1; then packages+=(vulkan-tools); fi
if ! command -v aplay >/dev/null 2>&1; then packages+=(alsa-utils); fi
mapfile -t core_packages < <(apt-cache pkgnames 'libretro-*' | sed '/^$/d' | grep -Ev '(-dev|-dbg|-dbgsym)$|^kodi-game-libretro$' | sort -u)
packages+=("${core_packages[@]}")
advanced_packages=()
if [[ $ADVANCED_CORES == yes ]]; then
    for candidate in libretro-pcsx-rearmed libretro-pcsx-redux libretro-mupen64plus-next libretro-parallel-n64 libretro-ppsspp libretro-flycast; do
        if apt-cache show "$candidate" >/dev/null 2>&1; then advanced_packages+=("$candidate"); fi
    done
    packages+=("${advanced_packages[@]}")
    if [[ $DOWNLOAD_ADVANCED == yes ]]; then
        command -v curl >/dev/null 2>&1 || packages+=(curl)
        command -v unzip >/dev/null 2>&1 || packages+=(unzip)
        command -v file >/dev/null 2>&1 || packages+=(file)
    fi
fi

if [[ $EMULATIONSTATION == yes ]]; then
    if apt-cache show emulationstation >/dev/null 2>&1; then
        packages+=(emulationstation)
    else
        warn 'EmulationStation is not available in the configured repositories; continuing with RetroArch only.'
    fi
fi

if [[ $REPAIR == no ]]; then
    ((${#packages[@]} > 0)) || die 'No RetroArch packages are available in the configured APT repositories.'
    printf 'RetroArch packages selected:\n  %s\n' "${packages[*]}"
    if [[ $UPDATE == yes ]]; then apt-get update; else echo 'Using the existing apt cache; no apt update was run.'; fi
    declare -a new_packages=()
    for package in "${packages[@]}"; do
        if ! dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null | grep -q '^ii '; then
            new_packages+=("$package")
        fi
    done
    apt-get install -y --no-install-recommends "${packages[@]}"
    install -d -m 755 /etc/orangepi-zero3w-setup/state
    state_file=/etc/orangepi-zero3w-setup/state/retroarch-packages
    touch "$state_file"
    for package in "${new_packages[@]}"; do
        grep -Fxq "$package" "$state_file" || printf '%s\n' "$package" >> "$state_file"
    done
fi
if [[ $AUTO_AUDIO == yes ]]; then
    if ! command -v speaker-test >/dev/null 2>&1; then
        warn 'speaker-test is unavailable; retaining the configured ALSA device.'
    else
        for candidate in default plughw:CARD=allwinnerhdmi,DEV=0; do
            log "Trying ALSA playback device: $candidate"
            set +e
            timeout 4s speaker-test -D "$candidate" -c 2 -r 48000 -F S16_LE -t wav -l 1 >/tmp/orangepi-retroarch-audio-test.log 2>&1
            audio_status=$?
            set -e
            if [[ $audio_status -eq 0 ]]; then
                AUDIO_DEVICE=$candidate
                log "Selected ALSA playback device: $AUDIO_DEVICE"
                break
            fi
        done
        rm -f /tmp/orangepi-retroarch-audio-test.log
    fi
fi

CFG_DIR="$USER_HOME/.config/retroarch"
CFG="$CFG_DIR/retroarch.cfg"
if [[ $DOWNLOAD_ADVANCED == yes ]]; then
    download_dir=$(mktemp -d)
    trap 'rm -rf "$download_dir"' EXIT
    install -d -m 755 /usr/lib/aarch64-linux-gnu/libretro
    install -d -m 755 "$CORE_CACHE_DIR"
    core_latest_url=${RETROARCH_CORE_BASE_URL:-https://buildbot.libretro.com/nightly/linux/aarch64/latest}
    for core_name in pcsx_rearmed mednafen_psx_hw parallel_n64 ppsspp flycast; do
        cached_zip="$CORE_CACHE_DIR/${core_name}_libretro.so.zip"
        cached_hash="$cached_zip.sha256"
        core_zip="$download_dir/${core_name}_libretro.so.zip"
        core_source="$download_dir/${core_name}_libretro.so"
        if [[ -s $cached_zip && -s $cached_hash ]] && (cd "$CORE_CACHE_DIR" && sha256sum -c "$(basename -- "$cached_hash")" >/dev/null 2>&1); then
            log "Reusing cached hash-verified aarch64 Libretro core: $core_name"
            cp -a "$cached_zip" "$core_zip"
        else
            core_base_url=${RETROARCH_CORE_PINNED_BASE_URL:-$core_latest_url}
            if [[ -n ${RETROARCH_CORE_PINNED_BASE_URL:-} ]]; then
                log "Downloading pinned aarch64 Libretro core: $core_name"
            else
                log "No cached or pinned archive for $core_name; falling back to official latest aarch64 build"
            fi
            curl --fail --location --retry 3 --silent --show-error \
                "$core_base_url/${core_name}_libretro.so.zip" -o "$core_zip"
            unzip -tqq "$core_zip"
            cp -a "$core_zip" "$cached_zip"
            (cd "$CORE_CACHE_DIR" && sha256sum "$(basename -- "$cached_zip")" >"$(basename -- "$cached_hash")")
        fi
        unzip -tqq "$core_zip"
        unzip -p "$core_zip" "${core_name}_libretro.so" > "$core_source"
        [[ -s $core_source ]] || die "Downloaded core archive did not contain ${core_name}_libretro.so"
        CORE_FILES+=" $core_source"
    done
fi
if [[ $ADVANCED_CORES == yes && -n ${CORE_FILES//[[:space:]]/} ]]; then
    read -r -a core_files <<< "$CORE_FILES"
    install -d -m 755 /usr/lib/aarch64-linux-gnu/libretro
    install -d -m 755 /etc/orangepi-zero3w-setup/state
    : > /etc/orangepi-zero3w-setup/state/retroarch-core-files
    for core_file in "${core_files[@]}"; do
        [[ -f $core_file ]] || die "Supplied core file does not exist: $core_file"
        [[ $core_file == *.so ]] || die "Supplied core must be an ARM64 Libretro .so file: $core_file"
        if command -v file >/dev/null 2>&1; then
            file_description=$(file -b "$core_file")
            grep -Eqi 'ARM aarch64|ARM 64-bit' <<<"$file_description" || die "Core is not identified as ARM64: $core_file ($file_description)"
        fi
        destination="/usr/lib/aarch64-linux-gnu/libretro/$(basename -- "$core_file")"
        install -m 755 "$core_file" "$destination"
        printf '%s\n' "$destination" >> /etc/orangepi-zero3w-setup/state/retroarch-core-files
        log "Installed supplied ARM64 Libretro core: $destination"
    done
fi
install -d -o "$TARGET_USER" -g "$USER_GROUP" -m 700 "$CFG_DIR"
if [[ $REPAIR == yes ]]; then
    latest_backup=$(ls -1t "$CFG".previous.* 2>/dev/null | head -n1 || true)
    if [[ -n $latest_backup ]]; then
        cp -a "$latest_backup" "$CFG"
        chown "$TARGET_USER:$USER_GROUP" "$CFG"
        chmod 600 "$CFG"
        log "Restored the most recent RetroArch configuration backup: $latest_backup"
    else
        warn "No RetroArch configuration backup found; creating or repairing $CFG."
    fi
fi
if [[ -f $CFG && $REPAIR == no ]]; then
    BACKUP="$CFG.previous.$(date -u +%Y%m%dT%H%M%SZ)"
    cp -a "$CFG" "$BACKUP"
    chown "$TARGET_USER:$USER_GROUP" "$BACKUP"
    chmod 600 "$BACKUP"
    log "Backed up RetroArch configuration to $BACKUP"
fi
touch "$CFG"

set_cfg() {
    local key=$1 value=$2 temp
    temp=$(mktemp)
    awk -v key="$key" -v value="$value" '
        $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
            if (!seen) { print key " = \"" value "\""; seen=1 }
            next
        }
        { print }
        END { if (!seen) print key " = \"" value "\"" }
    ' "$CFG" >"$temp"
    install -o "$TARGET_USER" -g "$USER_GROUP" -m 600 "$temp" "$CFG"
    rm -f "$temp"
}

set_cfg video_driver vulkan
set_cfg audio_driver alsa
set_cfg audio_device "$AUDIO_DEVICE"
set_cfg midi_driver null
set_cfg video_threaded false
set_cfg video_vsync true
for core_dir in /usr/lib/aarch64-linux-gnu/libretro /usr/lib/arm-linux-gnueabihf/libretro /usr/lib/libretro; do
    if [[ -d $core_dir ]]; then
        set_cfg libretro_directory "$core_dir"
        break
    fi
done
if [[ -s /etc/orangepi-zero3w-setup/state/retroarch-core-files ]]; then
    set_cfg libretro_directory /usr/lib/aarch64-linux-gnu/libretro
fi

cat >/usr/local/bin/retroarch-powervr <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
unset LD_LIBRARY_PATH
export DISPLAY="${DISPLAY:-:0}"
if [[ -n ${SSH_CONNECTION:-} && -z ${XAUTHORITY:-} && ! -S /tmp/.X11-unix/X0 ]]; then
    echo 'RetroArch PowerVR launcher requires the Orange Pi X11 desktop at :0.' >&2
    echo 'Launch it from the local desktop session or provide authorized X11 access.' >&2
    exit 1
fi
export VK_ICD_FILENAMES=/opt/pvr-ddk-24.2/vulkan/img_icd.json
exec /usr/bin/retroarch "$@"
EOF
chmod 755 /usr/local/bin/retroarch-powervr
cat >/usr/share/applications/retroarch-powervr.desktop <<'EOF'
[Desktop Entry]
Name=RetroArch (PowerVR Vulkan)
Comment=RetroArch using the Orange Pi PowerVR Vulkan driver
Exec=/usr/local/bin/retroarch-powervr
TryExec=/usr/local/bin/retroarch-powervr
Icon=retroarch
Terminal=false
Type=Application
Categories=Game;Emulator;
EOF
chmod 644 /usr/share/applications/retroarch-powervr.desktop

if [[ ${#core_packages[@]} -gt 0 ]]; then
    log "Installed libretro cores: ${core_packages[*]}"
else
    warn 'No Debian libretro runtime/core packages were found in the configured APT cache.'
fi
if [[ $ADVANCED_CORES == yes && ${#advanced_packages[@]} -eq 0 && -z ${CORE_FILES//[[:space:]]/} && $DOWNLOAD_ADVANCED != yes ]]; then
    warn 'No advanced PlayStation/N64/PSP/Dreamcast package is available in the configured repositories.'
    warn 'Supply ARM64 Libretro .so files with --core-file FILE or RETROARCH_CORE_FILES=...'
fi
log "Configured RetroArch for $TARGET_USER at $CFG"
log 'PowerVR libraries remain isolated; LD_LIBRARY_PATH was not configured globally.'
log 'Group changes require logout/login or reboot.'
log 'Launch with: retroarch-powervr'
log 'Optional audio test: sudo make board-retroarch-audio-test'
cat <<'EOF'
Core mapping: Nestopia NES; Snes9x SNES; BSNES Mercury Performance SNES;
Genesis Plus GX Genesis/Mega Drive/Master System/Game Gear; Gambatte Game Boy/
Game Boy Color; mGBA Game Boy Advance; DeSmuME Nintendo DS; Beetle VB Virtual
Boy; Beetle WonderSwan WonderSwan.
For this board, use Snes9x or BSNES Mercury Performance rather than Accuracy.
The current Debian repository may not provide PlayStation, N64, PSP, or
Dreamcast cores. Use board-retroarch-download-advanced for the official ARM64
buildbot cores, or supply reviewed ARM64 core files/source builds.
EOF
