#!/usr/bin/env bash
set -Eeuo pipefail

# WSL/Ubuntu host dependencies. Keep apt update explicit and user-invoked.
sudo apt-get install -y g++ libvulkan-dev mesa-vulkan-drivers vulkan-tools

if apt-cache show glslc >/dev/null 2>&1; then
    sudo apt-get install -y glslc
elif apt-cache show glslang-tools >/dev/null 2>&1; then
    sudo apt-get install -y glslang-tools
else
    echo 'ERROR: neither glslc nor glslang-tools is available in the apt cache.' >&2
    exit 1
fi

echo 'WSL/Ubuntu CPU Vulkan (Lavapipe) build dependencies installed.'
