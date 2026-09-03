#!/usr/bin/env bash
# Purpose: Check downloaded advanced Libretro cores and bounded RetroArch loading.
# Platform: arm64 Orange Pi board with retroarch-powervr and X11 display :0.
# Inputs: optional RETROARCH_USER and RETROARCH_CORE_DIR.
# Writes: temporary smoke-test logs only; core files and user configuration are read.
# Safety: never installs, downloads, changes configuration, or globally sets PVR paths.
# Repeat behavior: safe to repeat; missing optional cores are warnings.
# Recovery: download/reinstall the affected core, then rerun this check.
# Verification: checks ARM64 format, ldd dependencies, and RetroArch load evidence.
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root
CORE_DIR=${RETROARCH_CORE_DIR:-/usr/lib/aarch64-linux-gnu/libretro}
TARGET_USER=${RETROARCH_USER:-$(resolve_real_user)}
[[ $TARGET_USER != root ]] || die 'Refusing to test cores as root desktop user.'
id "$TARGET_USER" >/dev/null 2>&1 || die "User does not exist: $TARGET_USER"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
FAIL=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; FAIL=$((FAIL + 1)); }
warn() { printf 'WARN  %s\n' "$*"; }

printf 'RetroArch core check: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'core_directory=%s\n' "$CORE_DIR"
for core_name in pcsx_rearmed mednafen_psx_hw parallel_n64 ppsspp flycast; do
    core="$CORE_DIR/${core_name}_libretro.so"
    if [[ ! -f $core ]]; then warn "Missing optional core: $core"; continue; fi
    if command -v file >/dev/null 2>&1 && file -b "$core" | grep -Eqi 'ARM aarch64|ARM 64-bit'; then
        pass "$core_name is an ARM64 core"
    else
        fail "$core_name is not identified as an ARM64 core"
    fi
    dependencies=$(ldd "$core" 2>&1 || true)
    if grep -q 'not found' <<<"$dependencies"; then
        fail "$core_name has unresolved shared-library dependencies"
        grep 'not found' <<<"$dependencies"
    else
        pass "$core_name shared-library dependencies resolved"
    fi
    smoke_log=$(mktemp)
    set +e
    runuser -u "$TARGET_USER" -- env HOME="$USER_HOME" DISPLAY=:0 timeout 8s /usr/local/bin/retroarch-powervr -L "$core" --verbose --menu >"$smoke_log" 2>&1
    smoke_status=$?
    set -e
    if grep -Eq 'Loading dynamic libretro core|Core name:|Found display driver: "vulkan"' "$smoke_log"; then
        pass "$core_name loaded through RetroArch"
    else
        warn "$core_name load evidence was not observed (exit=$smoke_status)"
    fi
    rm -f "$smoke_log"
done
printf 'Summary: %d failed\n' "$FAIL"
((FAIL == 0))
