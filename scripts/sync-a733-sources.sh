#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
SOURCE_ROOT=${SOURCE_ROOT:-/opt/orangepi-zero3w-setup/sources}
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
        git clone "${repos[$name]}" "$destination"
    else
        echo "ERROR: source destination exists but is not a Git checkout: $destination" >&2
        exit 1
    fi
done
printf 'A733 source trees are under %s\n' "$SOURCE_ROOT"
