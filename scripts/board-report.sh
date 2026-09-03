#!/usr/bin/env bash
# Purpose: Collect one normalized, machine-readable board capability report.
# Platform: Orange Pi board with installed optional acceleration layers.
# Inputs: optional --output directory or BOARD_REPORT_OUTPUT.
# Writes: results.env, summary.txt, and component evidence below the output directory.
# Safety: diagnostics are read-only; secrets and private credentials must be sanitized.
# Repeat behavior: each invocation uses a new timestamped default directory.
# Recovery: rerun after a failed component check; prior reports remain intact.
# Verification: use compare-board-reports.sh for reports from multiple boards.
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo.' >&2; exit 1; }
OUTPUT=${BOARD_REPORT_OUTPUT:-/var/log/orangepi-zero3w-setup/board-report-$(date -u +%Y%m%dT%H%M%SZ)}
while (($#)); do
    case "$1" in
        --output) OUTPUT=${2:?}; shift 2;;
        -h|--help) echo "Usage: sudo $0 [--output DIRECTORY]"; exit 0;;
        *) echo "ERROR: unknown option: $1" >&2; exit 2;;
    esac
done

install -d -m 755 "$OUTPUT"
RESULTS="$OUTPUT/results.env"
SUMMARY="$OUTPUT/summary.txt"
: >"$RESULTS"
: >"$SUMMARY"
printf 'git_revision=%s\n' "$(git rev-parse --short HEAD 2>/dev/null || echo unknown)" >>"$RESULTS"

run_report() {
    local name=$1; shift
    local output="$OUTPUT/$name.txt"
    printf '===== %s =====\n' "$name" | tee -a "$SUMMARY"
    if "$@" >"$output" 2>&1; then
        printf 'PASS %s\n' "$name" | tee -a "$SUMMARY"
        printf '%s=PASS\n' "$name" >>"$RESULTS"
    else
        printf 'FAIL %s\n' "$name" | tee -a "$SUMMARY"
        printf '%s=FAIL\n' "$name" >>"$RESULTS"
    fi
}

run_report board-status ./scripts/board-status.sh
run_report gpu-abi ./scripts/board-gpu-abi-check.sh
run_report validation ./scripts/board-validation.sh
run_report headless-benchmark ./scripts/board-headless-benchmark.sh
run_report system-benchmark ./scripts/board-system-benchmark.sh
run_report storage-health ./scripts/board-storage-health.sh
run_report thermal-monitor ./scripts/board-thermal-monitor.sh -- ./scripts/board-headless-benchmark.sh
run_report diagnostics ./scripts/collect-diagnostics.sh "$OUTPUT/diagnostics.txt"

if grep -Eq '^[A-Za-z0-9_-]+=FAIL$' "$RESULTS"; then
    printf 'board_report_result=FAIL\n' >>"$RESULTS"
else
    printf 'board_report_result=PASS\n' >>"$RESULTS"
fi
printf '\nResults: %s\nReport directory: %s\n' "$RESULTS" "$OUTPUT" | tee -a "$SUMMARY"
grep -q '^board_report_result=PASS$' "$RESULTS"
