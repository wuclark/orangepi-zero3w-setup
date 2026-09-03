#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
UPDATE=no
if [[ ${1:-} == --update ]]; then
    UPDATE=yes
    shift
fi
[[ $# -eq 0 ]] || { echo "Usage: sudo $0 [--update]" >&2; exit 2; }
echo 'Optional software (nothing is selected by default):'
echo '  1) Diagnostics: htop jq tmux'
echo '  2) Build tools: git build-essential bc bison flex libssl-dev libelf-dev'
echo '  3) Python tools: python3 python3-venv python3-pip'
echo '  4) Docker and Compose: docker.io docker-compose'
echo '  5) Retro Gaming: RetroArch + PowerVR Vulkan'
echo '  6) Retro Gaming + optional EmulationStation (if available)'
echo '  7) Retro Gaming: available advanced cores from Debian repositories'
echo '  8) Retro Gaming: download official Libretro aarch64 advanced cores'
read -r -p 'Choose numbers separated by spaces, or press Enter for none: ' choices
[[ -n $choices ]] || { echo 'No optional software selected.'; exit 0; }
packages=()
retroarch_requested=no
emulationstation_requested=no
advanced_cores_requested=no
download_advanced_requested=no
for choice in $choices; do
    case "$choice" in
        1) packages+=(htop jq tmux) ;;
        2) packages+=(git build-essential bc bison flex libssl-dev libelf-dev) ;;
        3) packages+=(python3 python3-venv python3-pip) ;;
        4) packages+=(docker.io docker-compose) ;;
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
    args=(--install)
    [[ $UPDATE == yes ]] && args+=(--update)
    [[ $emulationstation_requested == yes ]] && args+=(--emulationstation)
    [[ $advanced_cores_requested == yes ]] && args+=(--advanced-cores)
    [[ $download_advanced_requested == yes ]] && args+=(--download-advanced)
    "$SCRIPT_DIR/install-retroarch.sh" "${args[@]}"
fi
