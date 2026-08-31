#!/usr/bin/env bash
set -Eeuo pipefail
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
echo '  4) Docker: docker.io'
read -r -p 'Choose numbers separated by spaces, or press Enter for none: ' choices
[[ -n $choices ]] || { echo 'No optional software selected.'; exit 0; }
packages=()
for choice in $choices; do
    case "$choice" in
        1) packages+=(htop jq tmux) ;;
        2) packages+=(git build-essential bc bison flex libssl-dev libelf-dev) ;;
        3) packages+=(python3 python3-venv python3-pip) ;;
        4) packages+=(docker.io) ;;
        *) echo "Unknown choice: $choice" >&2; exit 2 ;;
    esac
done
printf 'Will install: %s\n' "${packages[*]}"
read -r -p 'Continue? [y/N] ' confirm
[[ $confirm =~ ^[Yy]$ ]] || { echo 'Cancelled.'; exit 0; }
if [[ $UPDATE == yes ]]; then
    apt-get update
else
    echo 'Using the existing apt cache; no apt update was run.'
fi
apt-get install -y --no-install-recommends "${packages[@]}"
