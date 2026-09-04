#!/usr/bin/env bash
# Purpose: Compare normalized results from multiple collected board reports.
# Platform: Host workstation; operates on repository/work evidence and does not require a board.
# Inputs: REPORT_DIR or --equivalent environment selection and optional COMPARISON_OUTPUT.
# Dependencies: Bash, find, awk, sort, and tee.
# Writes: A comparison text report at COMPARISON_OUTPUT, defaulting inside REPORT_DIR.
# Safety: Read-only with respect to board/system state; only creates or replaces the requested comparison output.
# Repeat: Repeating regenerates the comparison from the current `results.env` files.
# Recovery: Restore or remove only the generated comparison output if it was created at an unwanted path.
# Outputs: Per-board result/revision table, per-check values, and PASS/FAIL exit status.
# Verification: Confirm every expected board has a valid results.env and PASS result.
# Documentation: docs/development/evidence-format.md
set -Eeuo pipefail

REPORT_DIR=${REPORT_DIR:-}
[[ -n "$REPORT_DIR" ]] || { echo 'ERROR: set REPORT_DIR=work/board-reports/TIMESTAMP.' >&2; exit 2; }
[[ -d "$REPORT_DIR" ]] || { echo "ERROR: report directory not found: $REPORT_DIR" >&2; exit 2; }
OUTPUT=${COMPARISON_OUTPUT:-"$REPORT_DIR/comparison.txt"}
mapfile -t reports < <(find "$REPORT_DIR" -mindepth 2 -maxdepth 2 -type f -name results.env | sort)
[[ ${#reports[@]} -gt 0 ]] || { echo "ERROR: no board results found under $REPORT_DIR" >&2; exit 2; }

overall=0
{
    echo 'Orange Pi board report comparison'
    echo "report_dir=$REPORT_DIR"
    echo
    printf '%-32s %-12s %s\n' board result revision
    printf '%-32s %-12s %s\n' '--------------------------------' '------------' '--------'
    for result in "${reports[@]}"; do
        board=$(basename "$(dirname "$result")")
        report_result=$(awk -F= '$1 == "board_report_result" {print $2}' "$result")
        revision=$(awk -F= '$1 == "git_revision" {print $2}' "$result")
        : "${report_result:=UNKNOWN}"
        : "${revision:=unknown}"
        printf '%-32s %-12s %s\n' "$board" "$report_result" "$revision"
        [[ "$report_result" == PASS ]] || overall=1
    done
    echo
    echo 'Per-check results:'
    for result in "${reports[@]}"; do
        board=$(basename "$(dirname "$result")")
        printf '%s: ' "$board"
        awk -F= '$1 != "board_report_result" && $1 != "git_revision" {printf "%s=%s ", $1, $2}' "$result"
        echo
    done
    echo
    if ((overall == 0)); then echo 'comparison_result=PASS'; else echo 'comparison_result=FAIL'; fi
} | tee "$OUTPUT"
exit "$overall"
