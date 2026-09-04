#!/usr/bin/env bash
# Purpose: Install board-side Vulkan compute compiler and development dependencies.
# Platform: Orange Pi target board using the existing Debian apt cache.
# Inputs: Current apt cache; no command-line options.
# Dependencies: Bash, root, apt-get, apt-cache, g++, libvulkan-dev, and glslc or glslang-tools availability.
# Writes: Installs selected Debian packages; does not change GPU boot ordering or application configuration.
# Safety: Deliberately never runs apt update; package installation is the only system mutation.
# Repeat: apt-get safely converges already-installed packages and repeats compiler selection.
# Recovery: Remove the optional packages with apt if the compute layer is no longer needed.
# Outputs: Package-manager diagnostics and a dependency-installed confirmation.
# Verification: Run `sudo make board-gpu-compute-test` after installation.
# Documentation: docs/optional/gpu/gpu.md
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
