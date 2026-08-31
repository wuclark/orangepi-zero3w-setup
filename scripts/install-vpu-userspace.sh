#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

VENDOR_ROOT=""
while (($#)); do
    case "$1" in
        --vendor-root) VENDOR_ROOT=${2:?}; shift 2 ;;
        -h|--help) echo "Usage: sudo $0 --vendor-root ROOT"; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done
[[ -d $VENDOR_ROOT ]] || die "Vendor root not found: $VENDOR_ROOT"

# The upstream archive is assembled from libcedarc and GStreamer OMX package
# manifests. Copy only its documented runtime roots, never its entire tree.
[[ -d $VENDOR_ROOT/usr/lib ]] || die "VPU archive is missing usr/lib."
BACKUP_ROOT="/var/backups/$PROJECT_NAME/vpu-$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 700 "$BACKUP_ROOT"

copy_tree() {
    local source="$VENDOR_ROOT/$1" item relative destination
    [[ -e $source ]] || return 0
    while IFS= read -r -d '' item; do
        relative=${item#"$VENDOR_ROOT/"}
        destination="/$relative"
        if [[ -d $item && ! -L $item ]]; then
            install -d -m 755 "$destination"
        else
            backup_file "$destination" "$BACKUP_ROOT"
            install -d -m 755 "$(dirname "$destination")"
            cp -a -- "$item" "$destination"
        fi
    done < <(find "$source" -depth -print0)
}

copy_tree usr/lib
copy_tree usr/bin
copy_tree etc/xdg/gstomx.conf
copy_tree etc/udev/rules.d/99-cedar-ve.rules

ldconfig
udevadm control --reload-rules
udevadm trigger
log "Installed optional Cedar/GStreamer OMX userspace; backup: $BACKUP_ROOT"
