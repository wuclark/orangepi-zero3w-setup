#!/usr/bin/env bash
# Purpose: Sample thermal, frequency, throttle, and power sensors during a command.
# Platform: running Orange Pi board exposing Linux thermal/cpufreq/hwmon sysfs.
# Inputs: --interval, --duration, --output, or a command after `--`.
# Writes: timestamped samples and the monitored command result to the output file.
# Safety: read-only monitoring; the child command itself determines its side effects.
# Repeat behavior: safe to repeat and suitable for bounded benchmark monitoring.
# Recovery: inspect the final command status and samples; no persistent repair occurs.
# Verification: correlate samples with workload results and kernel diagnostics.
set -Eeuo pipefail

OUTPUT=${OUTPUT:-/var/log/orangepi-zero3w-setup/thermal-monitor-$(date -u +%Y%m%dT%H%M%SZ).txt}
INTERVAL=${INTERVAL:-1}
DURATION=
COMMAND=()
while (($#)); do
    case "$1" in
        --output) OUTPUT=${2:?missing file after --output}; shift 2 ;;
        --interval) INTERVAL=${2:?missing seconds after --interval}; shift 2 ;;
        --duration) DURATION=${2:?missing seconds after --duration}; shift 2 ;;
        --) shift; COMMAND=("$@"); break ;;
        -h|--help)
            echo "Usage: $0 [--output FILE] [--interval SECONDS] [--duration SECONDS] [-- COMMAND ...]"
            exit 0
            ;;
        *) echo "ERROR: use -- before the command to monitor" >&2; exit 2 ;;
    esac
done
[[ $INTERVAL =~ ^[0-9]+([.][0-9]+)?$ && $INTERVAL != 0 ]] || { echo 'ERROR: interval must be positive' >&2; exit 2; }
if [[ -z $DURATION && ${#COMMAND[@]} -eq 0 ]]; then
    echo 'ERROR: supply --duration or a command after --' >&2
    exit 2
fi
if [[ -n $DURATION ]]; then
    [[ $DURATION =~ ^[0-9]+([.][0-9]+)?$ && $DURATION != 0 ]] || { echo 'ERROR: duration must be positive' >&2; exit 2; }
fi

install -d -m 755 "$(dirname "$OUTPUT")"
exec > >(tee "$OUTPUT") 2>&1

sample() {
    local zone temp type min_freq max_freq sum count path value name
    printf 'sample_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for zone in /sys/class/thermal/thermal_zone*; do
        [[ -r $zone/temp ]] || continue
        temp=$(<"$zone/temp")
        type=$(<"$zone/type")
        printf 'temperature_%s_c=%.3f\n' "$type" "$(awk -v t="$temp" 'BEGIN {print t / 1000}')"
    done
    min_freq=0; max_freq=0; sum=0; count=0
    for path in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        [[ -r $path ]] || continue
        value=$(<"$path"); count=$((count + 1)); sum=$((sum + value))
        ((min_freq == 0 || value < min_freq)) && min_freq=$value
        ((value > max_freq)) && max_freq=$value
    done
    if ((count > 0)); then
        printf 'cpu_frequency_khz_avg=%d\n' "$((sum / count))"
        printf 'cpu_frequency_khz_min=%d\n' "$min_freq"
        printf 'cpu_frequency_khz_max=%d\n' "$max_freq"
    fi
    for path in /sys/devices/system/cpu/cpu*/thermal_throttle/*_throttle_count; do
        [[ -r $path ]] || continue
        name=${path##*/}; name=${name%_throttle_count}
        printf 'throttle_%s_total=%s\n' "$name" "$(<"$path")"
    done
    for path in /sys/class/hwmon/hwmon*/{name,power*_input,voltage*_input,current*_input}; do
        [[ -r $path ]] || continue
        printf 'sensor_%s=%s\n' "${path##*/}" "$(<"$path")"
    done
}

echo "Orange Pi thermal/power monitor: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
uname -a
if ((${#COMMAND[@]} > 0)); then
    echo "monitored_command=${COMMAND[*]}"
    "${COMMAND[@]}" &
    child=$!
fi
start=$(date +%s.%N)
while :; do
    sample
    if [[ -n $DURATION ]]; then
        elapsed=$(awk -v now="$(date +%s.%N)" -v start="$start" 'BEGIN {print now - start}')
        awk -v elapsed="$elapsed" -v duration="$DURATION" 'BEGIN {exit !(elapsed >= duration)}' && break
    elif ! kill -0 "$child" 2>/dev/null; then
        break
    fi
    sleep "$INTERVAL"
done
result=0
if ((${#COMMAND[@]} > 0)); then
    wait "$child" || result=$?
fi
echo "monitor_result=$result"
exit "$result"
