#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

MINUTES=${STABILITY_MINUTES:-30}
STORAGE=${STABILITY_STORAGE:-no}
INTERVAL=${STABILITY_INTERVAL_SECONDS:-0}
OUTPUT=${STABILITY_OUTPUT:-/var/log/orangepi-zero3w-setup/stability-test-$(date -u +%Y%m%dT%H%M%SZ).txt}
CSV_OUTPUT=${STABILITY_CSV_OUTPUT:-${OUTPUT%.txt}.csv}
GRAPH_OUTPUT=${STABILITY_GRAPH_OUTPUT:-${OUTPUT%.txt}.png}
[[ $MINUTES =~ ^[1-9][0-9]*$ ]] || die 'STABILITY_MINUTES must be a positive integer.'
[[ $STORAGE == yes || $STORAGE == no ]] || die 'STABILITY_STORAGE must be yes or no.'
[[ $INTERVAL =~ ^[0-9]+$ ]] || die 'STABILITY_INTERVAL_SECONDS must be zero or a positive integer.'

install -d -m 755 "$(dirname -- "$OUTPUT")"
install -d -m 755 "$(dirname -- "$CSV_OUTPUT")" "$(dirname -- "$GRAPH_OUTPUT")"
exec > >(tee "$OUTPUT") 2>&1

printf 'iteration,epoch_utc,sample_utc,cpub_c,gpu_c,npu_c,ddr_c,skin_c,result\n' >"$CSV_OUTPUT"

TEMP_CPUB=
TEMP_GPU=
TEMP_NPU=
TEMP_DDR=
TEMP_SKIN=

sample_health() {
    local zone temp type path value
    TEMP_CPUB=; TEMP_GPU=; TEMP_NPU=; TEMP_DDR=; TEMP_SKIN=
    SAMPLE_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    printf 'sample_utc=%s\n' "$SAMPLE_UTC"
    for zone in /sys/class/thermal/thermal_zone*; do
        [[ -r $zone/temp && -r $zone/type ]] || continue
        temp=$(<"$zone/temp")
        type=$(<"$zone/type")
        printf 'temperature_%s_c=%.3f\n' "$type" "$(awk -v t="$temp" 'BEGIN {print t / 1000}')"
        case "$type" in
            cpub_thermal_zone) TEMP_CPUB=$(awk -v t="$temp" 'BEGIN {printf "%.3f", t / 1000}') ;;
            gpu_thermal_zone) TEMP_GPU=$(awk -v t="$temp" 'BEGIN {printf "%.3f", t / 1000}') ;;
            npu_thermal_zone) TEMP_NPU=$(awk -v t="$temp" 'BEGIN {printf "%.3f", t / 1000}') ;;
            ddr_thermal_zone) TEMP_DDR=$(awk -v t="$temp" 'BEGIN {printf "%.3f", t / 1000}') ;;
            skin_zone) TEMP_SKIN=$(awk -v t="$temp" 'BEGIN {printf "%.3f", t / 1000}') ;;
        esac
    done
    for path in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        [[ -r $path ]] || continue
        value=$(<"$path")
        printf 'cpu_frequency_khz=%s\n' "$value"
    done
}

ascii_graph() {
    local label value bar
    printf 'Temperature snapshot: '
    for label in CPU GPU NPU DDR; do
        case "$label" in
            CPU) value=${TEMP_CPUB:-0} ;;
            GPU) value=${TEMP_GPU:-0} ;;
            NPU) value=${TEMP_NPU:-0} ;;
            DDR) value=${TEMP_DDR:-0} ;;
        esac
        bar=$(awk -v t="$value" 'BEGIN {n=int(t); if (n < 0) n=0; if (n > 80) n=80; for (i=0; i<n; i++) printf "#"}')
        printf '%s=%sC [%s] ' "$label" "$value" "$bar"
    done
    echo
}

ascii_history_graph() {
    command -v gnuplot >/dev/null 2>&1 || return 0
    echo 'Temperature history (C):'
    gnuplot <<GNUPLOT
set datafile separator ','
set terminal dumb 110 24
set title 'Temperature history'
set xlabel 'Iteration'
set ylabel 'C'
set key outside
set grid
plot '$CSV_OUTPUT' every ::1 using 1:4 with linespoints title 'CPU', \
     '$CSV_OUTPUT' every ::1 using 1:5 with linespoints title 'GPU', \
     '$CSV_OUTPUT' every ::1 using 1:6 with linespoints title 'NPU', \
     '$CSV_OUTPUT' every ::1 using 1:7 with linespoints title 'DDR'
GNUPLOT
}

printf 'Orange Pi stability test: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
uname -a
printf 'duration_minutes=%s\n' "$MINUTES"
printf 'storage_benchmark=%s\n' "$STORAGE"
printf 'iteration_interval_seconds=%s\n' "$INTERVAL"
echo "To change duration: sudo make board-stability-test STABILITY_MINUTES=MINUTES"
echo 'Default duration is 30 minutes with no interval between iterations; storage testing is disabled unless STABILITY_STORAGE=yes is supplied.'
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
    ascii_graph
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
        result_label=PASS
    else
        printf 'RESULT: FAIL - stability iteration (exit=%d)\n' "$result"
        failures=$((failures + 1))
        result_label=FAIL
    fi
    printf '%d,%d,%s,%s,%s,%s,%s,%s,%s\n' "$iteration" "$(date +%s)" "$SAMPLE_UTC" \
        "${TEMP_CPUB:-}" "${TEMP_GPU:-}" "${TEMP_NPU:-}" "${TEMP_DDR:-}" "${TEMP_SKIN:-}" "$result_label" >>"$CSV_OUTPUT"
    ascii_history_graph
    (( $(date +%s) >= deadline )) && break
    if ((INTERVAL == 0)); then
        echo 'Continuing immediately with the next iteration (interval=0).'
    else
        echo "Waiting $INTERVAL seconds before the next iteration..."
    fi
    sleep "$INTERVAL"
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
echo '===== TEMPERATURE SUMMARY ====='
awk -F, 'NR > 1 {for (i = 4; i <= 8; i++) if ($i != "") {sum[i] += $i; count[i]++; if (!(i in min) || $i < min[i]) min[i] = $i; if (!(i in max) || $i > max[i]) max[i] = $i}} END {names[4]="CPU"; names[5]="GPU"; names[6]="NPU"; names[7]="DDR"; names[8]="Skin"; for (i = 4; i <= 8; i++) if (count[i]) printf "%s: min=%.1fC max=%.1fC avg=%.1fC\n", names[i], min[i], max[i], sum[i] / count[i]}' "$CSV_OUTPUT"
if command -v gnuplot >/dev/null 2>&1; then
    gnuplot -e "csv='$CSV_OUTPUT'; png='$GRAPH_OUTPUT'" > /dev/null 2>&1 <<'GNUPLOT'
set datafile separator ','
set terminal pngcairo size 1200,700 noenhanced
set output png
set title 'Orange Pi stability temperatures'
set xlabel 'Iteration'
set ylabel 'Temperature (C)'
set key outside
set grid
plot csv every ::1 using 1:4 with linespoints title 'CPU', \
     csv every ::1 using 1:5 with linespoints title 'GPU', \
     csv every ::1 using 1:6 with linespoints title 'NPU', \
     csv every ::1 using 1:7 with linespoints title 'DDR', \
     csv every ::1 using 1:8 with linespoints title 'Skin'
GNUPLOT
    echo "Temperature graph saved to $GRAPH_OUTPUT"
else
    echo 'WARNING: gnuplot is unavailable; install it with sudo make board-system-benchmark-deps.'
fi
echo "CSV data saved to $CSV_OUTPUT"
echo "Evidence saved to $OUTPUT"
((failures == 0))
