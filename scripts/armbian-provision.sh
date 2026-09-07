#!/usr/bin/env bash
# Purpose: Interactively install explicitly selected optional Armbian software.
# Platform: Orange Pi Zero 3W board installation; run as root on the target.
# Inputs: Optional --update and interactive package/feature selections and confirmation.
# Dependencies: Bash, apt-get, and repository helpers for selected RetroArch features.
# Writes: Installs selected Debian packages and may configure RetroArch and its optional assets.
# Safety: Nothing is selected by default; apt metadata refresh occurs only with --update.
# Repeat: Repeating the flow is package-manager idempotent; each run requires interactive confirmation.
# Recovery: Uninstall optional layers with their documented repository targets; no automatic rollback is provided.
# Outputs: Selection summary, apt/install output, and delegated RetroArch results.
# Verification: Verify installed options with the corresponding `make` status or validation target.
# Documentation: docs/development/development.md
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
UPDATE=no
if [[ ${1:-} == --update ]]; then
    UPDATE=yes
    shift
fi
[[ $# -eq 0 ]] || { echo "Usage: sudo $0 [--update]" >&2; exit 2; }
PVR_ROOT=${PVR_ROOT:-/opt/pvr-ddk-24.2}
# Package-group state shown in the menu below. Re-selecting installed
# packages is harmless (apt is idempotent); the tags only save deliberation.
pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}
group_installed() {
    local p
    for p in "$@"; do pkg_installed "$p" || return 1; done
}
menu_tag() {
    if group_installed "$@"; then printf ' [installed]'; fi
}
gpu_layer_ready() {
    [[ -f $PVR_ROOT/vulkan/img_icd.json && -d /dev/dri ]] && lsmod | grep -q '^pvrsrvkm '
}
g1=(htop jq tmux)
g2=(git build-essential bc bison flex libssl-dev libelf-dev)
g3=(python3 python3-venv python3-pip)
g4=(docker.io docker-compose)
echo 'Optional software (nothing is selected by default):'
echo "  1) Diagnostics: htop jq tmux$(menu_tag "${g1[@]}")"
echo "  2) Build tools: git build-essential bc bison flex libssl-dev libelf-dev$(menu_tag "${g2[@]}")"
echo "  3) Python tools: python3 python3-venv python3-pip$(menu_tag "${g3[@]}")"
echo "  4) Docker and Compose: docker.io docker-compose$(menu_tag "${g4[@]}")"
echo "  5) Retro Gaming: RetroArch + PowerVR Vulkan$(menu_tag retroarch retroarch-assets libretro-core-info)"
echo '  6) Retro Gaming + optional EmulationStation (if available)'
echo '  7) Retro Gaming: available advanced cores from Debian repositories'
echo '  8) Retro Gaming: download official Libretro aarch64 advanced cores'
if gpu_layer_ready; then
    echo '  (Board GPU layer: ready.)'
else
    echo '  (Board GPU layer: not installed — RetroArch options 5-8 will skip configuration until it is.)'
fi
read -r -p 'Choose numbers separated by spaces, or press Enter for none: ' choices
[[ -n $choices ]] || { echo 'No optional software selected.'; exit 0; }
packages=()
retroarch_requested=no
emulationstation_requested=no
advanced_cores_requested=no
download_advanced_requested=no
for choice in $choices; do
    case "$choice" in
        1) packages+=("${g1[@]}") ;;
        2) packages+=("${g2[@]}") ;;
        3) packages+=("${g3[@]}") ;;
        4) packages+=("${g4[@]}") ;;
        5) retroarch_requested=yes ;;
        6) retroarch_requested=yes; emulationstation_requested=yes ;;
        7) retroarch_requested=yes; advanced_cores_requested=yes ;;
        8) retroarch_requested=yes; advanced_cores_requested=yes; download_advanced_requested=yes ;;
        *) echo "Unknown choice: $choice" >&2; exit 2 ;;
    esac
done
if [[ ${#packages[@]} -gt 0 ]]; then
    printf 'Will install: %s\n' "${packages[*]}"
fi
[[ $retroarch_requested == yes ]] && echo 'Will configure: RetroArch + PowerVR Vulkan'
read -r -p 'Continue? [y/N] ' confirm
[[ $confirm =~ ^[Yy]$ ]] || { echo 'Cancelled.'; exit 0; }
if [[ $UPDATE == yes ]]; then
    apt-get update
else
    echo 'Using the existing apt cache; no apt update was run.'
fi
if [[ ${#packages[@]} -gt 0 ]]; then
    apt-get install -y --no-install-recommends "${packages[@]}"
fi
if [[ $retroarch_requested == yes ]]; then
    # Same prerequisites as install-retroarch.sh: configuring RetroArch
    # without the GPU layer always fails late, so skip up front and let the
    # rest of the setup continue. Debian packages selected above stay
    # installed; only the PowerVR configuration step is deferred.
    if ! gpu_layer_ready; then
        echo 'SKIP: RetroArch PowerVR configuration needs the board GPU layer first.'
        echo "Missing at least one of: $PVR_ROOT/vulkan/img_icd.json, /dev/dri, loaded pvrsrvkm."
        echo 'Continuing without RetroArch configuration.'
        echo 'After the GPU layer works (sudo make board-gpu-install, reboot, sudo make board-gpu-verify),'
        echo 'run: sudo make board-retroarch-install (see make help board-retroarch-* for the selected extras).'
    else
        args=(--install)
        [[ $UPDATE == yes ]] && args+=(--update)
        [[ $emulationstation_requested == yes ]] && args+=(--emulationstation)
        [[ $advanced_cores_requested == yes ]] && args+=(--advanced-cores)
        [[ $download_advanced_requested == yes ]] && args+=(--download-advanced)
        "$SCRIPT_DIR/install-retroarch.sh" "${args[@]}"
    fi
fi
