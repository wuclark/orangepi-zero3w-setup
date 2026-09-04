#!/usr/bin/env bash
# Purpose: Install WSL/Ubuntu CPU Vulkan compute test dependencies using Mesa Lavapipe.
# Platform: WSL2/Ubuntu host only; this does not test Orange Pi PowerVR hardware.
# Inputs: Current apt cache and available glslc or glslang-tools package.
# Dependencies: Bash, sudo, apt-get, apt-cache, and network/package metadata when packages are absent.
# Writes: Installs host compiler, Vulkan, Mesa, and Vulkan tool packages.
# Safety: Does not run apt update; uses sudo only for package installation.
# Repeat: apt-get safely converges already-installed host packages.
# Recovery: Remove the optional WSL Vulkan packages with apt if no longer needed.
# Outputs: Package-manager diagnostics and Lavapipe dependency confirmation.
# Verification: Run `make wsl-vulkan-compute-test` and confirm the CPU Vulkan baseline.
# Documentation: docs/optional/gpu/gpu.md
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
