#!/usr/bin/env bash
# Purpose: Render a sanitized Markdown summary from a board-report directory.
# Platform: Orange Pi board holding a completed board-report plus validation evidence.
# Inputs: Optional --report DIR (default: latest board-report) and --output FILE.
# Dependencies: Bash, root-readable report files, and well-known evidence logs.
# Writes: One sanitized SUMMARY.md (default inside the report directory).
# Safety: Read-only over inputs; aborts when secret-like patterns are found and
#          redacts LAN IPv4 addresses before writing.
# Repeat: Safe to repeat; the output is rewritten from the same inputs.
# Recovery: Rerun the missing source target named by any "not recorded" section.
# Outputs: Markdown with status, validation, and performance tables for an issue.
# Verification: Every table row traces to a cited source file; secrets abort.
# Documentation: docs/guide/06-fresh-install-showcase.md
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

LOGDIR=/var/log/orangepi-zero3w-setup
REPORT=$(ls -d "$LOGDIR"/board-report-* 2>/dev/null | sort | tail -n 1 || true)
OUTPUT=""
while (($#)); do
    case "$1" in
        --report) REPORT=${2:?}; shift 2 ;;
        --output) OUTPUT=${2:?}; shift 2 ;;
        -h|--help)
            echo "Usage: sudo $0 [--report DIR] [--output FILE]"
            exit 0
            ;;
        *) die "Unknown argument: $1" ;;
    esac
done
[[ -n $REPORT && -f $REPORT/results.env ]] || die "No board report found; run 'sudo make board-report' first"
[[ -f $REPORT/validation.txt ]] || die "$REPORT/validation.txt is missing; rerun board-report"
OUTPUT=${OUTPUT:-$REPORT/SUMMARY.md}

pick() { grep -hoE "$2" "$1" 2>/dev/null | head -n 1 || true; }
first_match_file() {
    local pattern=$1; shift
    grep -hE "$pattern" "$@" 2>/dev/null | head -n 20 || true
}

# Version identifiers are evidence, not secrets: capture them before the IP
# redaction pass and restore them through placeholders afterwards.
FWVER=$(pick "$REPORT/diagnostics.txt" 'rgx\.fw\.[0-9.]*')
NPUVER=$(pick "$REPORT/headless-benchmark.txt" 'VIPLite driver software version [^ ]*')
VKDRV=$(grep -hoE '[0-9]+\.[0-9]+@[0-9]+' "$REPORT/diagnostics.txt" 2>/dev/null | head -n 1 || true)

{
    printf '# Board performance summary\n\n'
    printf 'Generated: %s  \nSource report: %s  \n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$REPORT"
    printf 'Git revision: %s\n\n' "$(grep -h '^git_revision=' "$REPORT/results.env" 2>/dev/null | cut -d= -f2 || echo unknown)"

    printf '## Stack\n\n'
    printf '| Component | Value |\n| --- | --- |\n'
    printf '| OS | %s |\n' "$(pick "$REPORT/diagnostics.txt" 'PRETTY_NAME=.*' | cut -d= -f2- | tr -d '"')"
    printf '| Kernel | %s |\n' "$(grep -h '^Linux ' "$REPORT/validation.txt" | head -n 1 | awk '{print $3}')"
    printf '| Vulkan driver | %s |\n' "${VKDRV:-not recorded}"
    printf '| Firmware | %s |\n' "__FWVER__"
    printf '| NPU runtime | %s |\n' "__NPUVER__"
    printf '\n## Checks\n\n| Check | Result |\n| --- | --- |\n'
    grep -h -E '^[A-Za-z0-9_-]+=(PASS|FAIL|SKIP)$' "$REPORT/results.env" | sed -E 's/=/ | /; s/^/| /; s/$/ |/'

    printf '\n## Validation detail\n\n| Check | Result |\n| --- | --- |\n'
    grep -h -E '^RESULT: (PASS|FAIL|SKIP) - ' "$REPORT/validation.txt" | sed -E 's/^RESULT: (PASS|FAIL|SKIP) - (.*)/| \2 | \1 |/'

    printf '\n## Performance\n\n'
    printf '### GPU Vulkan compute\n\n```text\n'
    if [[ -s $LOGDIR/vulkan-compute-validation.txt ]]; then
        first_match_file 'gpu_ms_per_dispatch|result_errors|device=PowerVR' "$LOGDIR/vulkan-compute-validation.txt"
    else
        printf 'not recorded; run: sudo make board-gpu-compute-test\n'
    fi
    printf '```\n\n### VPU decode quality (Cedar vs software)\n\n```text\n'
    if [[ -s $LOGDIR/vpu-quality-validation.txt ]]; then
        first_match_file '^(file|codec|padded|hw_frames|psnr_avg|ssim_all)=' "$LOGDIR/vpu-quality-validation.txt"
    else
        printf 'not recorded; run: sudo make board-vpu-quality-test\n'
    fi
    printf '```\n\n### VPU decode speed (Cedar vs software fps)\n\n```text\n'
    if grep -q '^PASS: .* speedup=' "$REPORT/headless-benchmark.txt" 2>/dev/null; then
        grep -h '^PASS: .* speedup=' "$REPORT/headless-benchmark.txt"
    elif [[ -s $LOGDIR/vpu-decode-speed.txt ]]; then
        first_match_file '^(file|codec|hw_sec)=' "$LOGDIR/vpu-decode-speed.txt"
    else
        printf 'not recorded; run: sudo make board-vpu-decode-speed\n'
    fi
    printf '```\n\n### NPU inference\n\n```text\n'
    if [[ -s $LOGDIR/npu-validation.txt ]]; then
        first_match_file 'profile avg inference|vpm run ret|VIPLite driver software version' "$LOGDIR/npu-validation.txt"
    else
        printf 'not recorded; run: sudo make board-npu-install (then verify)\n'
    fi
    printf '```\n'
} > "$OUTPUT.raw"

if grep -rEin 'password|passwd|wireless|ssid|\bpsk\b|secret|token|api[_-]?key|BEGIN .*PRIVATE KEY' "$OUTPUT.raw" >/tmp/zero3w-summary-secrets.txt 2>/dev/null; then
    printf 'Secret-like patterns found; refusing to write. Inspect:\n' >&2
    cat /tmp/zero3w-summary-secrets.txt >&2
    rm -f -- "$OUTPUT.raw" /tmp/zero3w-summary-secrets.txt
    exit 1
fi
rm -f -- /tmp/zero3w-summary-secrets.txt
sed -E -e 's/127\.0\.0\.1/LOOPBACK/g' -e 's/\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b/x.x.x.x/g' -e 's/LOOPBACK/127.0.0.1/g' "$OUTPUT.raw" > "$OUTPUT"
rm -f -- "$OUTPUT.raw"
sed -i "s|__FWVER__|${FWVER:-not recorded}|; s|__NPUVER__|${NPUVER:-not recorded}|" "$OUTPUT"
printf '\nSanitized: LAN IPv4 addresses redacted; generation aborts on secret-like patterns. Attach the cited evidence files to the issue.\n' >> "$OUTPUT"
printf 'Summary saved to %s\n' "$OUTPUT"
