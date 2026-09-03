#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BACKUP_SET=${BACKUP_SET:-}
BACKUP_DIR=${BACKUP_DIR:-}

while (($#)); do
    case "$1" in
        --set) BACKUP_SET=${2:?}; shift 2;;
        --destination) BACKUP_DIR=${2:?}; shift 2;;
        -h|--help) echo 'Usage: make backup-required|backup-cache|backup-sensitive|backup-all BACKUP_DIR=PATH'; exit 0;;
        *) echo "ERROR: unknown option: $1" >&2; exit 2;;
    esac
done

if [[ -z "$BACKUP_DIR" ]]; then
    read -r -p 'Backup destination: ' BACKUP_DIR
fi
[[ -n "$BACKUP_DIR" ]] || { echo 'ERROR: backup destination is required.' >&2; exit 2; }
case "$BACKUP_SET" in required|cache|sensitive|all) ;; *) echo 'ERROR: choose required, cache, sensitive, or all.' >&2; exit 2;; esac

if [[ "$BACKUP_SET" == sensitive || "$BACKUP_SET" == all ]]; then
    if [[ ${BACKUP_CONFIRM:-} != YES ]]; then
        read -r -p 'This includes passwords and Wi-Fi credentials. Type BACKUP SENSITIVE to continue: ' confirmation
        [[ "$confirmation" == 'BACKUP SENSITIVE' ]] || { echo 'Sensitive backup cancelled.' >&2; exit 2; }
    fi
fi

mkdir -p "$BACKUP_DIR"
printf 'backup_utc=%s\nrepository=%s\ngit_revision=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$REPO_ROOT" \
    "$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)" \
    >"$BACKUP_DIR/backup-info.txt"

copy_one() {
    local set_name=$1 relative=$2 source="$REPO_ROOT/$2" destination="$BACKUP_DIR/$1/$2"
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
    printf '  %s\n' "$relative"
}

copy_matches() {
    local set_name=$1 required=$2 pattern match found=0
    local -a matches
    shift 2
    for pattern in "$@"; do
        shopt -s nullglob
        matches=("$REPO_ROOT"/$pattern)
        shopt -u nullglob
        for match in "${matches[@]}"; do
            found=1
            copy_one "$set_name" "${match#"$REPO_ROOT/"}"
        done
        if ((found == 0)) && ((required)); then
            echo "ERROR: required backup input is missing: $pattern" >&2
            return 1
        fi
        if ((found == 0)) && ((! required)); then
            case "$pattern" in
                work/vendor-output/*)
                    echo 'INFO: vendor output is absent; run `make extract` to regenerate it.' >&2
                    ;;
                testdata/videos/*)
                    echo 'INFO: VPU test data is absent; run `make board-vpu-generate-videos` (all) or `make board-vpu-generate-decode-videos` (two decode files).' >&2
                    ;;
                work/images/armbian/*preloaded*.img|work/images/armbian/*.sha256|work/images/armbian/*.manifest.txt|work/images/armbian/.last-final-image)
                    echo 'INFO: derived image output is absent; run `make image` or `make newsd` to rebuild it.' >&2
                    ;;
            esac
        fi
        found=0
    done
}

copy_any() {
    local set_name=$1 label=$2 pattern match found=0
    local -a matches
    shift 2
    for pattern in "$@"; do
        shopt -s nullglob
        matches=("$REPO_ROOT"/$pattern)
        shopt -u nullglob
        for match in "${matches[@]}"; do
            found=1
            copy_one "$set_name" "${match#"$REPO_ROOT/"}"
        done
    done
    if ((found == 0)); then
        echo "ERROR: required backup input is missing: $label" >&2
        case "$label" in
            'matching kernel source')
                echo 'ACTION: run `make kernel-source` to fetch the sparse orange-pi-6.6-sun60iw2 checkout, then rerun this backup.' >&2
                ;;
            'AI SDK')
                echo 'ACTION: place the AI SDK archive at work/images/ai-sdk.tar.gz, then rerun this backup.' >&2
                ;;
            'Orange Pi source image'|'Radxa source image'|'Armbian base image')
                echo 'ACTION: restore or download the matching source image under work/images/, then rerun this backup.' >&2
                ;;
        esac
        return 1
    fi
}

write_manifest() {
    local set_name=$1 directory="$BACKUP_DIR/$1"
    [[ -d "$directory" ]] || return 0
    (cd "$directory" && find . -type f ! -name manifest.sha256 -print0 | sort -z | xargs -0 -r sha256sum) >"$directory/manifest.sha256"
}

backup_required() {
    local set_name=required
    mkdir -p "$BACKUP_DIR/$set_name"
    copy_any "$set_name" 'Orange Pi source image' \
        'work/images/Orangepizero3w_*.img' 'work/images/Orangepizero3w_*.img.xz' 'work/images/Orangepizero3w_*.img.7z'
    copy_any "$set_name" 'Radxa source image' \
        'work/images/radxa-*.img' 'work/images/radxa-*.img.xz' 'work/images/radxa-*.img.7z'
    copy_any "$set_name" 'Armbian base image' \
        'work/images/armbian/*minimal.img' 'work/images/armbian/*minimal.img.xz' 'work/images/armbian/*minimal.img.7z'
    copy_any "$set_name" 'AI SDK' 'work/images/ai-sdk.tar.gz'
    copy_any "$set_name" 'matching kernel source' 'build-pvrsrvkm/linux-orangepi'
    [[ -d "$REPO_ROOT/vendor-files" ]] && copy_one "$set_name" vendor-files
    [[ -d "$REPO_ROOT/vendor-root" ]] && copy_one "$set_name" vendor-root
    write_manifest "$set_name"
}

backup_cache() {
    local set_name=cache
    mkdir -p "$BACKUP_DIR/$set_name"
    copy_matches "$set_name" 0 \
        'work/vendor-output/*' \
        'testdata/videos/*' \
        'work/images/armbian/*preloaded*.img' \
        'work/images/armbian/*.sha256' \
        'work/images/armbian/*.manifest.txt' \
        'work/images/armbian/.last-final-image'
    write_manifest "$set_name"
}

backup_sensitive() {
    local set_name=sensitive
    mkdir -p -m 700 "$BACKUP_DIR/$set_name"
    copy_matches "$set_name" 0 not_logged_in_yet provisioning.sh
    write_manifest "$set_name"
    chmod -R go-rwx "$BACKUP_DIR/$set_name"
}

case "$BACKUP_SET" in
    required) backup_required;;
    cache) backup_cache;;
    sensitive) backup_sensitive;;
    all) backup_required; backup_cache; backup_sensitive;;
esac

chmod 600 "$BACKUP_DIR/backup-info.txt"
echo "Backup complete: $BACKUP_DIR ($BACKUP_SET)"
