#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

MINUTES=${STABILITY_MINUTES:-30}
STORAGE=${STABILITY_STORAGE:-no}
OUTPUT=${STABILITY_OUTPUT:-/var/log/orangepi-zero3w-setup/stability-test-$(date -u +%Y%m%dT%H%M%SZ).txt}
[[ $MINUTES =~ ^[1-9][0-9]*$ ]] || die 'STABILITY_MINUTES must be a positive integer.'
[[ $STORAGE == yes || $STORAGE == no ]] || die 'STABILITY_STORAGE must be yes or no.'

install -d -m 755 "$(dirname -- "$OUTPUT")"
exec > >(tee "$OUTPUT") 2>&1

sample_health() {
    local zone temp type path value
    printf 'sample_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for zone in /sys/class/thermal/thermal_zone*; do
        [[ -r $zone/temp && -r $zone/type ]] || continue
        temp=$(<"$zone/temp")
        type=$(<"$zone/type")
        printf 'temperature_%s_c=%.3f\n' "$type" "$(awk -v t="$temp" 'BEGIN {print t / 1000}')"
    done
    for path in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        [[ -r $path ]] || continue
        value=$(<"$path")
        printf 'cpu_frequency_khz=%s\n' "$value"
    done
}

printf 'Orange Pi stability test: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
uname -a
printf 'duration_minutes=%s\n' "$MINUTES"
printf 'storage_benchmark=%s\n' "$STORAGE"
echo "To change duration: sudo make board-stability-test STABILITY_MINUTES=MINUTES"
echo 'Default duration is 30 minutes; storage testing is disabled unless STABILITY_STORAGE=yes is supplied.'
echo 'Repeats headless GPU/VPU/NPU workloads and records temperatures.'
echo 'Storage mode writes a temporary benchmark file; use it only when intended.'

baseline=$(mktemp)
current=$(mktemp)
trap 'rm -f "$baseline" "$current"' EXIT
dmesg --color=never >"$baseline" || true
start=$(date +%s)
deadline=$((start + MINUTES * 60))
iteration=0
failures=0

while (( $(date +%s) < deadline || iteration == 0 )); do
    iteration=$((iteration + 1))
    echo
    printf '===== ITERATION %d =====\n' "$iteration"
    sample_health
    set +e
    timeout 120s "$SCRIPT_DIR/board-headless-benchmark.sh"
    result=$?
    if [[ $STORAGE == yes ]]; then
        timeout 180s "$SCRIPT_DIR/board-system-benchmark.sh" --storage
        storage_result=$?
        ((storage_result == 0)) || result=$storage_result
    fi
    set -e
    if ((result == 0)); then
        echo 'RESULT: PASS - stability iteration'
    else
        printf 'RESULT: FAIL - stability iteration (exit=%d)\n' "$result"
        failures=$((failures + 1))
    fi
    (( $(date +%s) >= deadline )) && break
    sleep 30
done

dmesg --color=never >"$current" || true
echo
echo '===== NEW KERNEL WARNINGS/ERRORS ====='
if comm -13 <(sort "$baseline") <(sort "$current") | grep -Ei 'error|fail|timeout|oops|panic|I/O|mmc|sdio'; then
    echo 'Review the lines above; some vendor-driver messages may be known noise.'
else
    echo 'No new matching kernel messages observed.'
fi
printf '\nSUMMARY: iterations=%d failures=%d\n' "$iteration" "$failures"
echo "Evidence saved to $OUTPUT"
((failures == 0))
