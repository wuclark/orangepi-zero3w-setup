#!/usr/bin/env bash
# Purpose: Clone or fast-forward the repository's pinned A733 source trees.
# Platform: Orange Pi target board or approved development environment with Git/network access.
# Inputs: SOURCE_ROOT and GIT_DEPTH environment variables.
# Dependencies: Bash, root, git, and network access to the configured source repositories.
# Writes: Git checkouts under SOURCE_ROOT, defaulting to /opt/orangepi-zero3w-setup/sources.
# Safety: Refuses to overwrite a non-Git destination; uses fast-forward-only updates for existing checkouts.
# Repeat: Reuses existing repositories and fast-forwards them; new repositories use the requested clone depth.
# Recovery: Remove only a confirmed source checkout and rerun, or restore the prior commit manually.
# Outputs: Source checkout/update diagnostics and the final source root path.
# Verification: Inspect each checkout's Git revision before using source-derived artifacts.
# Documentation: docs/development/development.md
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
SOURCE_ROOT=${SOURCE_ROOT:-/opt/orangepi-zero3w-setup/sources}
GIT_DEPTH=${GIT_DEPTH:-1}
install -d -m 755 "$SOURCE_ROOT"

declare -A repos=(
    [a733_npu_driver]=https://github.com/wuclark/a733_npu_driver.git
    [ai-sdk]=https://github.com/wuclark/ai-sdk.git
    [radxa-a7a-toolkit]=https://github.com/wuclark/radxa-a7a-toolkit.git
    [a733-powervr-fex]=https://github.com/wuclark/a733-powervr-fex.git
)

for name in "${!repos[@]}"; do
    destination="$SOURCE_ROOT/$name"
    if [[ -d "$destination/.git" ]]; then
        git -C "$destination" pull --ff-only
    elif [[ ! -e $destination ]]; then
        if [[ $GIT_DEPTH == 0 ]]; then
            git clone "${repos[$name]}" "$destination"
        else
            git clone --depth "$GIT_DEPTH" "${repos[$name]}" "$destination"
        fi
    else
        echo "ERROR: source destination exists but is not a Git checkout: $destination" >&2
        exit 1
    fi
done
printf 'A733 source trees are under %s\n' "$SOURCE_ROOT"
