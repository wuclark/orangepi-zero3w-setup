#!/usr/bin/env bash
# Purpose: Measure CPU, compression, crypto, memory, optional storage/network results.
# Platform: arm64 Orange Pi board with benchmark dependencies installed from APT.
# Inputs: --storage, --network HOST, and --output; storage/network are opt-in.
# Writes: timestamped evidence and, with --storage, a temporary 256 MiB test file.
# Safety: storage mode writes the selected root storage; network mode needs a peer.
# Repeat behavior: safe to repeat; results depend on thermal state and background load.
# Recovery: temporary storage data is removed after the fio test; inspect failed logs.
# Verification: each section reports PASS/FAIL and the final summary is authoritative.
set -Eeuo pipefail

OUTPUT=${OUTPUT:-/var/log/orangepi-zero3w-setup/system-benchmark-$(date -u +%Y%m%dT%H%M%SZ).txt}
STORAGE=no
NETWORK_HOST=
while (($#)); do
    case "$1" in
        --storage) STORAGE=yes; shift ;;
        --network) NETWORK_HOST=${2:?missing host after --network}; shift 2 ;;
        --output) OUTPUT=${2:?missing file after --output}; shift 2 ;;
        -h|--help)
            echo "Usage: sudo $0 [--storage] [--network HOST] [--output FILE]"
            exit 0
            ;;
        *) echo "ERROR: unknown option: $1" >&2; exit 2 ;;
    esac
done
[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo.' >&2; exit 1; }
if [[ $STORAGE == yes ]]; then
    command -v fio >/dev/null || { echo 'ERROR: fio is required; run sudo make board-system-benchmark-deps' >&2; exit 1; }
fi
if [[ -n $NETWORK_HOST ]]; then
    command -v iperf3 >/dev/null || { echo 'ERROR: iperf3 is required; run sudo make board-system-benchmark-deps' >&2; exit 1; }
fi
for command in sysbench 7z openssl mbw; do
    command -v "$command" >/dev/null || { echo "ERROR: $command is required; run sudo make board-system-benchmark-deps" >&2; exit 1; }
done

install -d -m 755 "$(dirname "$OUTPUT")"
exec > >(tee "$OUTPUT") 2>&1
PASS=0; FAIL=0
run_benchmark() {
    local name=$1; shift; local result
    printf '\n===== %s =====\n' "$name"
    set +e
    "$@"
    result=$?
    set -e
    if ((result == 0)); then PASS=$((PASS + 1)); printf 'RESULT: PASS - %s\n' "$name";
    else FAIL=$((FAIL + 1)); printf 'RESULT: FAIL - %s\n' "$name"; fi
}

echo "Headless Orange Pi system benchmark: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
uname -a
run_benchmark 'CPU sysbench' sysbench cpu --cpu-max-prime=20000 --threads="$(nproc)" run
run_benchmark '7-Zip benchmark' 7z b -mmt="$(nproc)"
run_benchmark 'OpenSSL SHA-256 speed' openssl speed -seconds 3 sha256
run_benchmark 'Memory bandwidth' mbw -n 3 256

if [[ $STORAGE == yes ]]; then
    storage_file=/var/tmp/orangepi-zero3w-fio-test.bin
    echo 'WARNING: storage benchmark writes a 256 MiB test file to /var/tmp.'
    run_benchmark 'Storage fio' fio --name=orangepi-storage --filename="$storage_file" \
        --size=256M --rw=readwrite --bs=1M --direct=1 --iodepth=1 \
        --runtime=20 --time_based --group_reporting
    rm -f -- "$storage_file"
fi

if [[ -n $NETWORK_HOST ]]; then
    run_benchmark "Network iperf3 to $NETWORK_HOST" iperf3 --client "$NETWORK_HOST" --time 10
fi

printf '\n===== SUMMARY =====\nPASS: %d  FAIL: %d\n' "$PASS" "$FAIL"
printf 'Evidence saved to %s\n' "$OUTPUT"
((FAIL == 0))
