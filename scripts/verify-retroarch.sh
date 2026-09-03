#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

TARGET_USER=${RETROARCH_USER:-$(resolve_real_user)}
[[ $TARGET_USER != root ]] || die 'Refusing to validate RetroArch under /root; specify RETROARCH_USER.'
id "$TARGET_USER" >/dev/null 2>&1 || die "User does not exist: $TARGET_USER"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
CFG="$USER_HOME/.config/retroarch/retroarch.cfg"
FAIL=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; FAIL=$((FAIL + 1)); }
warn() { printf 'WARN  %s\n' "$*"; }

printf 'RetroArch PowerVR validation: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'target_user=%s\n' "$TARGET_USER"
[[ -x /usr/local/bin/retroarch-powervr ]] && pass 'PowerVR launcher exists' || fail 'Missing PowerVR launcher; run the installer.'
[[ -x /usr/bin/retroarch ]] && pass 'RetroArch is installed' || fail 'RetroArch is not installed.'
[[ -f "$PVR_ROOT/vulkan/img_icd.json" ]] && pass 'PowerVR Vulkan ICD exists' || fail 'PowerVR Vulkan ICD is missing.'
command -v vulkaninfo >/dev/null 2>&1 && pass 'vulkaninfo is available' || fail 'vulkaninfo is missing; install vulkan-tools.'

if [[ -r "$PVR_ROOT/vulkan/img_icd.json" ]] && command -v vulkaninfo >/dev/null 2>&1; then
    vulkan_output=$(env -u LD_LIBRARY_PATH VK_ICD_FILENAMES="$PVR_ROOT/vulkan/img_icd.json" vulkaninfo --summary 2>&1 || true)
    grep -Fq 'PowerVR B-Series BXM-4-64 MC1' <<<"$vulkan_output" && pass 'Vulkan detects the expected PowerVR GPU' || fail 'Vulkan did not identify the expected PowerVR GPU'
fi

cfg_value() { awk -v key="$1" '$0 ~ "^[[:space:]]*" key "[[:space:]]*=" { sub(/^[^=]*=[[:space:]]*/, ""); gsub(/[[:space:]]+$/, ""); print; exit }' "$CFG" 2>/dev/null || true; }
if [[ -f $CFG ]]; then
    for key in video_driver audio_driver audio_device midi_driver video_threaded video_vsync; do
        value=$(cfg_value "$key")
        [[ -n $value ]] && pass "RetroArch $key is configured" || fail "RetroArch $key is missing"
    done
    [[ $(cfg_value video_driver) == '"vulkan"' ]] || fail 'RetroArch video_driver is not vulkan'
    [[ $(cfg_value audio_driver) == '"alsa"' ]] || fail 'RetroArch audio_driver is not alsa'
    [[ $(cfg_value midi_driver) == '"null"' ]] || fail 'RetroArch midi_driver is not null'
else
    fail "Missing RetroArch configuration: $CFG"
fi

if [[ -S /tmp/.X11-unix/X0 ]]; then
    smoke_log=$(mktemp)
    trap 'rm -f "$smoke_log"' EXIT
    set +e
    runuser -u "$TARGET_USER" -- env HOME="$USER_HOME" DISPLAY=:0 timeout 10s /usr/local/bin/retroarch-powervr --verbose >"$smoke_log" 2>&1
    set -e
    grep -Fq 'Found vulkan context: "vk_x"' "$smoke_log" && pass 'RetroArch selected the X11 Vulkan context' || fail 'RetroArch did not select the X11 Vulkan context'
    grep -Fq 'PowerVR B-Series BXM-4-64 MC1' "$smoke_log" && pass 'RetroArch selected the PowerVR GPU' || fail 'RetroArch did not select the PowerVR GPU'
    grep -Fq 'Found display server: "x11"' "$smoke_log" && pass 'RetroArch found the X11 display server' || fail 'RetroArch did not find X11; check session authorization'
    grep -Eq 'Got [0-9]+ swapchain images' "$smoke_log" && pass 'RetroArch created an X11 Vulkan swapchain' || warn 'RetroArch swapchain evidence was not observed before the bounded test ended'
else
    warn 'X11 display :0 is not available; run validation from the desktop session or provide authorized X11 access.'
    warn 'SSH without X11 authorization can produce a null Vulkan context even when vulkaninfo detects PowerVR.'
fi

if command -v aplay >/dev/null 2>&1 && aplay -l 2>/dev/null | grep -qi allwinnerhdmi; then
    pass 'Known allwinnerhdmi playback device exists'
    audio_log=$(mktemp)
    trap 'rm -f "$audio_log"' EXIT
    set +e
    timeout 4s speaker-test -D default -c 2 -r 48000 -F S16_LE -t wav -l 1 >"$audio_log" 2>&1
    audio_status=$?
    set -e
    if [[ $audio_status -eq 0 ]]; then pass 'ALSA default playback test completed'; else warn 'ALSA default playback test did not complete; try the explicit HDMI plughw device.'; fi
else
    warn 'Known allwinnerhdmi playback hardware was not found; audio validation skipped.'
fi

cat <<'EOF'
Core mapping: Nestopia NES; Snes9x SNES; BSNES Mercury Performance SNES;
Genesis Plus GX Genesis/Mega Drive/Master System/Game Gear; Gambatte Game Boy/
Game Boy Color; mGBA Game Boy Advance; DeSmuME Nintendo DS; Beetle VB Virtual
Boy; Beetle WonderSwan WonderSwan.
For this board, use Snes9x or BSNES Mercury Performance rather than Accuracy.
The current repository does not provide PlayStation, N64, PSP, or Dreamcast
cores; those require manually downloaded ARM64 cores or source builds.
EOF
printf 'Summary: %d failed\n' "$FAIL"
((FAIL == 0))
