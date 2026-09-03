#!/usr/bin/env bash
# Purpose: Extract allowlisted runtime files from already mounted source roots.
# Platform: native Linux/WSL2 host; this tool does not mount or install anything.
# Inputs: one --source-root or separate GPU/VPU and NPU roots plus --output-dir.
# Writes: generated userspace archives and file/hash manifests in the output directory.
# Safety: applies explicit path allowlists and keeps proprietary results outside Git.
# Repeat behavior: output is generated as a private derived artifact for validation.
# Recovery: inspect the source/output manifests and rerun after correcting inputs.
# Verification: run tests/test-archives.sh and prepare-vendor-archives.sh.
set -Eeuo pipefail

usage() {
    cat <<'EOF'
Usage: extract-vendor-userspace.sh [--source-root ROOT] [options]

Extract GPU/VPU and NPU userspace from mounted or unpacked root filesystems.
Use --gpu-vpu-root for the Radxa source and --npu-root for the Orange Pi
source. --source-root uses one root for all components and is useful for tests.

Options:
  --gpu-vpu-root ROOT  GPU/VPU source root (normally Radxa)
  --npu-root ROOT      NPU source root (normally Orange Pi)
  --output-dir DIR     Output directory; must not already exist

This host-side tool does not install files, load modules, or mount disk images.
Use native Linux or WSL after mounting/extracting a verified source image.
EOF
}

SOURCE_ROOT=""
GPU_VPU_ROOT=""
NPU_ROOT=""
OUTPUT_DIR=""
progress() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
while (($#)); do
    case "$1" in
        --source-root) SOURCE_ROOT=${2:?}; shift 2 ;;
        --gpu-vpu-root) GPU_VPU_ROOT=${2:?}; shift 2 ;;
        --npu-root) NPU_ROOT=${2:?}; shift 2 ;;
        --output-dir) OUTPUT_DIR=${2:?}; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
    esac
done
if [[ -n $SOURCE_ROOT ]]; then
    GPU_VPU_ROOT=$SOURCE_ROOT
    NPU_ROOT=$SOURCE_ROOT
fi
[[ -n $GPU_VPU_ROOT && -n $NPU_ROOT ]] || {
    echo 'ERROR: provide --source-root or both --gpu-vpu-root and --npu-root' >&2; exit 2;
}
for root in "$GPU_VPU_ROOT" "$NPU_ROOT"; do
    [[ -d $root/etc && -d $root/usr ]] || {
        echo "ERROR: source root must contain etc/ and usr/: $root" >&2; exit 1;
    }
done
GPU_VPU_ROOT=$(cd -- "$GPU_VPU_ROOT" && pwd)
NPU_ROOT=$(cd -- "$NPU_ROOT" && pwd)
OUTPUT_DIR=${OUTPUT_DIR:-$(mktemp -d -t zero3w-vendor-output.XXXXXXXX)}
if [[ -e $OUTPUT_DIR ]]; then
    [[ -d $OUTPUT_DIR && -z $(find "$OUTPUT_DIR" -mindepth 1 ! -name .gitkeep -print -quit) ]] || {
        echo "ERROR: output must be absent or empty: $OUTPUT_DIR" >&2; exit 1;
    }
fi
install -d -m 700 "$OUTPUT_DIR"

WORK=$(mktemp -d -t zero3w-vendor-stage.XXXXXXXX)
PVR_STAGE=$WORK/pvr
VPU_STAGE=$WORK/vpu
NPU_STAGE=$WORK/npu
install -d -m 700 "$PVR_STAGE" "$VPU_STAGE" "$NPU_STAGE"
trap 'rm -rf -- "$WORK"' EXIT
CURRENT_STAGE=$PVR_STAGE
progress 'Collecting PowerVR userspace files'
SOURCE_ROOT=$GPU_VPU_ROOT

copy_path() {
    local path=$1 destination=${2:-$1} source="$SOURCE_ROOT/$1"
    [[ -f $source || -L $source ]] || return 0
    [[ $path != lib/modules/* && $path != usr/lib/modules/* ]] || return 0
    install -d -m 755 "$CURRENT_STAGE/$(dirname "$destination")"
    cp -a -- "$source" "$CURRENT_STAGE/$destination"
}

copy_manifest_files() {
    local manifest=$1 path destination
    [[ -f $manifest ]] || return 0
    while IFS= read -r path || [[ -n $path ]]; do
        [[ $path == /* ]] || continue
        path=${path#/}
        case "$path" in
            usr/include/*|usr/share/doc/*|usr/share/man/*|usr/share/metainfo/*|usr/bin/Xorg|etc/X11/*|usr/lib/systemd/*|lib/modules/*) continue ;;
        esac
        destination=$path
        [[ $destination == lib/* ]] && destination="usr/$destination"
        copy_path "$path" "$destination"
    done < "$manifest"
}

copy_glob() {
    local pattern=$1 item relative destination prefix=${2:-}
    while IFS= read -r -d '' item; do
        relative=${item#"$SOURCE_ROOT/"}
        destination=${prefix:+$prefix/}$(basename "$relative")
        [[ -n $prefix ]] || destination=$relative
        [[ $destination == lib/* ]] && destination="usr/$destination"
        copy_path "$relative" "$destination"
    done < <(find "$SOURCE_ROOT" \( -path "$SOURCE_ROOT/$pattern" -type f -o -path "$SOURCE_ROOT/$pattern" -type l \) -print0 2>/dev/null)
}

CURRENT_STAGE=$PVR_STAGE
for manifest in "$SOURCE_ROOT"/var/lib/dpkg/info/*img-bxm*.list; do
    copy_manifest_files "$manifest"
done
for pattern in lib/firmware/rgx.* usr/share/vulkan/icd.d/img_icd.json \
    etc/ld.so.conf.d/00_xserver-xorg-img-bxm.conf usr/local/lib/dri/pvr_dri.so \
    usr/lib/aarch64-linux-gnu/dri/pvr_dri.so; do
    copy_glob "$pattern"
done

CURRENT_STAGE=$VPU_STAGE
progress 'Collecting VPU userspace files'
SOURCE_ROOT=$GPU_VPU_ROOT
for manifest in "$SOURCE_ROOT"/var/lib/dpkg/info/libcedarc*.list \
    "$SOURCE_ROOT"/var/lib/dpkg/info/libgstreamer-openmax-allwinner.list \
    "$SOURCE_ROOT"/var/lib/dpkg/info/gstreamer1.0-omx*.list; do
    copy_manifest_files "$manifest"
done
copy_path etc/xdg/gstomx.conf
copy_path etc/cedarc.conf
copy_path lib/udev/rules.d/99-sunxi-ve.rules etc/udev/rules.d/99-cedar-ve.rules
copy_path etc/udev/rules.d/99-cedar-ve.rules

CURRENT_STAGE=$NPU_STAGE
progress 'Collecting NPU userspace files'
SOURCE_ROOT=$NPU_ROOT
for pattern in usr/lib/libvip*.so* usr/lib/lib*vip*.so* \
    usr/lib/aarch64-linux-gnu/libvip*.so* usr/lib/aarch64-linux-gnu/lib*vip*.so* \
    usr/lib/libgal*.so* usr/lib/aarch64-linux-gnu/libgal*.so* usr/share/vip* \
    etc/vip* etc/viplite*; do
    copy_glob "$pattern"
done
for pattern in usr/lib/libVIPhal.so* usr/lib/libNBGlinker.so* \
    usr/lib/aarch64-linux-gnu/libVIPhal.so* usr/lib/aarch64-linux-gnu/libNBGlinker.so* \
    home/orangepi/lib/libVIPhal.so* home/orangepi/lib/libNBGlinker.so* \
    opt/*/lib/libVIPhal.so* opt/*/lib/libNBGlinker.so*; do
    copy_glob "$pattern" usr/local/lib/npu
done

require_component() {
    local component=$1 stage=$2 pattern
    shift
    shift
    for pattern in "$@"; do
        compgen -G "$stage/$pattern" >/dev/null 2>&1 && return 0
    done
    echo "ERROR: no required $component userspace found" >&2
    exit 1
}
require_component pvr "$PVR_STAGE" usr/lib/libVK_IMG.so* usr/local/lib/dri/pvr_dri.so \
    usr/lib/aarch64-linux-gnu/dri/pvr_dri.so
require_component vpu "$VPU_STAGE" usr/lib/aarch64-linux-gnu/libvideoengine.so* \
    usr/lib/aarch64-linux-gnu/libOmxVdec.so* usr/lib/libcedarc* usr/lib/aarch64-linux-gnu/libcedarc*
require_component npu "$NPU_STAGE" usr/lib/libvip*.so* usr/lib/aarch64-linux-gnu/libvip*.so* \
    usr/lib/lib*vip*.so* usr/local/lib/npu/libVIPhal.so* usr/local/lib/npu/libNBGlinker.so*

for component in pvr vpu npu; do
    progress "Creating ${component} userspace archive"
    tar -C "$WORK/$component" --sort=name --mtime='UTC 1970-01-01' \
        --owner=0 --group=0 --numeric-owner -czf "$OUTPUT_DIR/${component}-userspace.tar.gz" .
    (cd "$OUTPUT_DIR" && sha256sum "${component}-userspace.tar.gz" > \
        "${component}-manifest.sha256")
done
for component in pvr vpu npu; do
    find "$WORK/$component" \( -type f -o -type l \) -printf "$component/%P\n" | sort
done > "$OUTPUT_DIR/files.txt"
progress "Created GPU, VPU, and NPU archives in $OUTPUT_DIR"
