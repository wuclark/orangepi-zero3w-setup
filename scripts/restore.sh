#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BACKUP_DIR=${BACKUP_DIR:-}
RESTORE_SET=${RESTORE_SET:-}

while (($#)); do
    case "$1" in
        --backup) BACKUP_DIR=${2:?}; shift 2;;
        --set) RESTORE_SET=${2:?}; shift 2;;
        --force) RESTORE_FORCE=1; shift;;
        -h|--help) echo 'Usage: make restore BACKUP_DIR=PATH RESTORE_SET=required|cache|sensitive|all'; exit 0;;
        *) echo "ERROR: unknown option: $1" >&2; exit 2;;
    esac
done

[[ -n "$BACKUP_DIR" ]] || { echo 'ERROR: set BACKUP_DIR=PATH.' >&2; exit 2; }
[[ -d "$BACKUP_DIR" ]] || { echo "ERROR: backup directory not found: $BACKUP_DIR" >&2; exit 2; }
case "$RESTORE_SET" in required|cache|sensitive|all) ;; *) echo 'ERROR: choose RESTORE_SET=required, cache, sensitive, or all.' >&2; exit 2;; esac

sets=("$RESTORE_SET")
[[ "$RESTORE_SET" == all ]] && sets=(required cache sensitive)
for set_name in "${sets[@]}"; do
    [[ -d "$BACKUP_DIR/$set_name" ]] || { echo "ERROR: backup set is missing: $set_name" >&2; exit 2; }
    [[ -f "$BACKUP_DIR/$set_name/manifest.sha256" ]] || { echo "ERROR: manifest is missing for: $set_name" >&2; exit 2; }
    (cd "$BACKUP_DIR/$set_name" && sha256sum -c manifest.sha256 >/dev/null) || {
        echo "ERROR: checksum verification failed for backup set: $set_name" >&2
        exit 1
    }
done

if [[ "$RESTORE_SET" == sensitive || "$RESTORE_SET" == all ]]; then
    if [[ ${RESTORE_FORCE:-} != 1 ]]; then
        read -r -p 'This restores passwords and Wi-Fi credentials. Type RESTORE SENSITIVE to continue: ' confirmation
        [[ "$confirmation" == 'RESTORE SENSITIVE' ]] || { echo 'Sensitive restore cancelled.' >&2; exit 2; }
    fi
fi

if [[ ${RESTORE_FORCE:-} != 1 ]]; then
    echo "The following backup set(s) will be restored into: $REPO_ROOT"
    printf '  %s\n' "${sets[@]}"
    read -r -p 'Type RESTORE to continue: ' confirmation
    [[ "$confirmation" == RESTORE ]] || { echo 'Restore cancelled.' >&2; exit 2; }
fi

for set_name in "${sets[@]}"; do
    echo "Restoring $set_name..."
    while read -r checksum relative; do
        relative=${relative#./}
        [[ -n "$relative" && "$relative" != /* && "$relative" != ../* && "$relative" != */../* ]] || {
            echo "ERROR: unsafe path in $set_name manifest: $relative" >&2
            exit 1
        }
        mkdir -p "$REPO_ROOT/$(dirname "$relative")"
        cp -a "$BACKUP_DIR/$set_name/$relative" "$REPO_ROOT/$relative"
    done < <(sed 's/[[:space:]]\+/ /' "$BACKUP_DIR/$set_name/manifest.sha256")
done

for set_name in "${sets[@]}"; do
    (cd "$BACKUP_DIR/$set_name" && sha256sum -c manifest.sha256 >/dev/null)
done
echo "Restore complete: $RESTORE_SET"
