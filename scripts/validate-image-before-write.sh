#!/usr/bin/env bash
set -Eeuo pipefail
IMAGE=${1:-}
usage() { echo "Usage: $0 IMAGE"; }
[[ -n $IMAGE && ${IMAGE:-} != -h && ${IMAGE:-} != --help ]] || { usage >&2; exit 2; }
[[ -f $IMAGE ]] || { echo "ERROR: image not found: $IMAGE" >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo 'ERROR: sha256sum is required' >&2; exit 1; }
command -v file >/dev/null 2>&1 || { echo 'ERROR: file is required' >&2; exit 1; }
command -v partx >/dev/null 2>&1 || { echo 'ERROR: partx is required' >&2; exit 1; }
checksum_file="$IMAGE.sha256"
[[ -f $checksum_file ]] || { echo "ERROR: checksum file not found: $checksum_file" >&2; exit 1; }
(cd "$(dirname "$IMAGE")" && sha256sum -c "$(basename "$checksum_file")")
description=$(file -b "$IMAGE")
grep -Eq 'boot sector|DOS/MBR|GPT' <<<"$description" || {
    echo "ERROR: image does not contain a recognized partitioned image: $description" >&2; exit 1;
}
partitions=$(partx -g -o NR,START,SECTORS -r "$IMAGE" 2>/dev/null || true)
[[ -n $partitions ]] || { echo 'ERROR: no partitions found in image' >&2; exit 1; }
printf 'image checksum: OK\npartition table: OK\n%s\n' "$description"
printf '%s\n' "$partitions"
printf 'Safe to write only after confirming this exact image path is the SD-card source.\n'
