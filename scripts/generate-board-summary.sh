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
NPUVER=$(pick "$REPORT/headless-benchmark.txt" 'VIPLite driver software version [^ ]*' | awk '{ print $NF }')
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
    printf '### GPU Vulkan compute\n\n'
    if [[ -s $LOGDIR/vulkan-compute-validation.txt ]]; then
        printf '| Kernel | ms/dispatch | Errors |\n| --- | --- | --- |\n'
        grep -hE 'gpu_ms_per_dispatch' "$LOGDIR/vulkan-compute-validation.txt" 2>/dev/null | awk '{ ms=""; err=""; for (i=1;i<=NF;i++) { if ($i ~ /^gpu_ms_per_dispatch=/) { split($i,a,"="); ms=a[2] } if ($i ~ /^result_errors=/) { split($i,b,"="); err=b[2] } } printf "| %s | %s | %s |\n", $1, ms, err }' || true
        dev=$(first_match_file '^device=' "$LOGDIR/vulkan-compute-validation.txt")
        [[ -n $dev ]] && printf '\n_Device: %s_\n' "$dev"
    else
        printf 'not recorded; run: sudo make board-gpu-compute-deps\n'
    fi
    printf '\n### VPU decode quality (Cedar vs software)\n\n'
    if [[ -s $LOGDIR/vpu-quality-validation.txt ]]; then
        first_match_file '^(file|codec|padded|hw_frames|psnr_avg|ssim_all)=' "$LOGDIR/vpu-quality-validation.txt" | awk 'BEGIN{ print "| File | Codec | Resolution | Frames | PSNR | SSIM |"; print "| --- | --- | --- | --- | --- | --- |" } /^file=/{ f=$1; sub(/^file=/,"",f) } /^codec=/{ split($1,c,"="); split($2,w,"="); split($3,h,"="); codec=c[2]; res=w[2]"x"h[2] } /^hw_frames=/{ split($1,n,"="); frames=n[2] } /^psnr_avg=/{ split($1,p,"="); split($2,s,"="); printf "| %s | %s | %s | %s | %s | %s |\n", f, codec, res, frames, p[2], s[2] }' || true
    else
        printf 'not recorded; run: sudo make board-vpu-quality-test\n'
    fi
    printf '\n### VPU decode speed (Cedar vs software fps)\n\n'
    if grep -q '^PASS: .* (cpu .* speedup=' "$REPORT/headless-benchmark.txt" 2>/dev/null; then
        speed_src="$REPORT/headless-benchmark.txt"
    elif [[ -s $LOGDIR/vpu-decode-speed.txt ]]; then
        speed_src="$LOGDIR/vpu-decode-speed.txt"
    else
        speed_src=""
    fi
    if [[ -n $speed_src ]]; then
        printf '| File | Frames | HW fps | SW fps | Speedup | HW CPU s | SW CPU s |\n| --- | --- | --- | --- | --- | --- | --- |\n'
        grep -h '^PASS: .* (cpu .* speedup=' "$speed_src" 2>/dev/null | awk '{ name=$2; frames=$3; hw=$7; sw=$12; spd=$14; hcpu=$6; scpu=$11; sub(/^frames=/,"",frames); sub(/,$/,"",hcpu); sub(/,$/,"",scpu); sub(/^speedup=/,"",spd); printf "| %s | %s | %s | %s | %s | %s | %s |\n", name, frames, hw, sw, spd, hcpu, scpu }' || true
    else
        printf 'not recorded; run: sudo make board-vpu-decode-speed\n'
    fi
    printf '\n### NPU inference\n\n'
    if [[ -s $LOGDIR/npu-validation.txt ]]; then
        printf '| Metric | Value |\n| --- | --- |\n'
        grep -hE 'VIPLite driver software version|profile avg inference time=|vpm run ret=' "$LOGDIR/npu-validation.txt" 2>/dev/null | awk '/VIPLite driver software version/{ sub(/^ */,""); printf "| Runtime | %s |\n", $0 } /profile avg inference time=/{ t=$0; sub(/.*profile avg inference time=/,"",t); printf "| Avg inference | %s |\n", t } /vpm run ret=/{ r=$0; sub(/.*vpm run ret=/,"",r); printf "| Smoke test return | %s |\n", r }' || true
    else
        printf 'not recorded; run: sudo make board-npu-install (then verify)\n'
    fi
    printf '\n'
} > "$OUTPUT.raw"

if grep -rEin 'password|passwd|wireless|ssid|\bpsk\b|secret|token|api[_-]?key|BEGIN .*PRIVATE KEY' "$OUTPUT.raw" >/tmp/zero3w-summary-secrets.txt 2>/dev/null; then
    printf 'Secret-like patterns found; refusing to write. Inspect:\n' >&2
    cat /tmp/zero3w-summary-secrets.txt >&2
    rm -f -- "$OUTPUT.raw" /tmp/zero3w-summary-secrets.txt
    exit 1
fi
rm -f -- /tmp/zero3w-summary-secrets.txt
# Shield version identifiers (evidence, not secrets) before the IP pass, then
# restore them from the captured values afterwards.
sed -E -e 's/rgx\.fw\.[0-9.]+/__FWVER__/g' -e 's/(VIPLite driver software version )[0-9.]+/\1__NPUVER__/g' "$OUTPUT.raw" > "$OUTPUT.tmp"
rm -f -- "$OUTPUT.raw"
sed -E -e 's/127\.0\.0\.1/LOOPBACK/g' -e 's/\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b/x.x.x.x/g' -e 's/LOOPBACK/127.0.0.1/g' "$OUTPUT.tmp" > "$OUTPUT"
rm -f -- "$OUTPUT.tmp"
sed -i "s|__FWVER__|${FWVER:-not recorded}|; s|__NPUVER__|${NPUVER:-not recorded}|" "$OUTPUT"
printf '\nSanitized: LAN IPv4 addresses redacted; generation aborts on secret-like patterns. Attach the cited evidence files to the issue.\n' >> "$OUTPUT"
printf 'Summary saved to %s\n' "$OUTPUT"
