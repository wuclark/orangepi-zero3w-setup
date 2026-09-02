#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo.' >&2; exit 1; }

# Deliberately do not run apt update. The board workflow uses the existing apt cache.
apt-get install -y g++ libvulkan-dev

if apt-cache show glslc >/dev/null 2>&1; then
    apt-get install -y glslc
elif apt-cache show glslang-tools >/dev/null 2>&1; then
    apt-get install -y glslang-tools
else
    echo 'ERROR: neither glslc nor glslang-tools is available in the apt cache.' >&2
    exit 1
fi

echo 'Vulkan compute build dependencies installed.'
