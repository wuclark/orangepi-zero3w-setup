#!/usr/bin/env bash
# Purpose: Collect normalized board reports from one or more boards over SSH.
# Platform: Host workstation with SSH access to supported Orange Pi boards.
# Inputs: BOARDS or --boards, REMOTE_REPO or --remote-repo, and output directory options.
# Dependencies: Bash, ssh, tar, make board-report on each remote board, and writable host output.
# Writes: Per-board logs, extracted report files, and summaries under the configured output directory.
# Safety: Reads board evidence and removes only its temporary remote report directory after retrieval.
# Repeat: Creates a new timestamped collection directory by default; existing explicit output may receive new files.
# Recovery: Preserve failed collection logs and rerun against the affected board; no board installation changes occur.
# Outputs: Board report files, collection logs, PASS/FAIL status, and an aggregate exit code.
# Verification: Review each summary and sanitize reports before sharing or committing evidence.
# Documentation: docs/development/evidence-format.md
set -Eeuo pipefail

BOARDS=${BOARDS:-}
REMOTE_REPO=${REMOTE_REPO:-'~/orangepi-zero3w-setup'}
OUTPUT=${BOARD_REPORTS_OUTPUT:-work/board-reports/$(date -u +%Y%m%dT%H%M%SZ)}

while (($#)); do
    case "$1" in
        --boards) BOARDS=${2:?}; shift 2;;
        --remote-repo) REMOTE_REPO=${2:?}; shift 2;;
        --output) OUTPUT=${2:?}; shift 2;;
        -h|--help) echo 'Usage: make collect-boards BOARDS="user@board1 user@board2" [REMOTE_REPO=PATH]'; exit 0;;
        *) echo "ERROR: unknown option: $1" >&2; exit 2;;
    esac
done

if [[ -z "$BOARDS" ]]; then
    read -r -p 'Boards (space-separated user@host values): ' BOARDS
fi
[[ -n "$BOARDS" ]] || { echo 'ERROR: at least one board is required.' >&2; exit 2; }
[[ "$REMOTE_REPO" != *"'"* ]] || { echo "ERROR: REMOTE_REPO may not contain a single quote." >&2; exit 2; }

mkdir -p "$OUTPUT"
overall=0
for board in $BOARDS; do
    safe_name=${board//[^A-Za-z0-9_.-]/_}
    board_dir="$OUTPUT/$safe_name"
    mkdir -p "$board_dir"
    remote_dir="/tmp/zero3w-board-report-$$-${safe_name}"
    printf '\n===== %s =====\n' "$board"
    report_status=0
    ssh "$board" "remote_repo='$REMOTE_REPO'; case \"\$remote_repo\" in '~/'*) remote_repo=\"\$HOME/\${remote_repo#~/}\";; esac; cd -- \"\$remote_repo\" && mkdir -p '$remote_dir' && make board-report BOARD_REPORT_OUTPUT='$remote_dir'" \
        >"$board_dir/collection.log" 2>&1 || report_status=$?
    if ssh "$board" "tar -C '$remote_dir' -czf - . && rm -rf '$remote_dir'" \
        >"$board_dir/report.tar.gz"; then
        tar -xzf "$board_dir/report.tar.gz" -C "$board_dir"
        rm -f "$board_dir/report.tar.gz"
        if ((report_status == 0)); then
            echo "PASS $board"
        else
            echo "FAIL $board (see $board_dir/summary.txt and collection.log)"
            overall=1
        fi
    else
        echo "FAIL $board (see $board_dir/collection.log)"
        overall=1
    fi
done

echo
echo "Reports saved to $OUTPUT"
exit "$overall"
