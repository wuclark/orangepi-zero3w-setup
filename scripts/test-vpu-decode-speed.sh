#!/usr/bin/env bash
# Purpose: Time Cedar hardware decode against software decode and report fps plus speedup.
# Platform: Orange Pi Zero 3W target board with VPU userspace and GStreamer installed.
# Inputs: Optional --output FILE, --media-dir DIR, --all for the full fixture set, --only BASENAME.
# Dependencies: Bash, root, GStreamer OMX decoders, ffmpeg/ffprobe, /etc/cedarc.conf.
# Writes: Raw yuv420p dumps in a private temp dir under /var/tmp (cleaned per file)
#          and optional timestamped speed evidence at OUTPUT.
# Safety: Headless bounded decodes only; does not present video, install packages, reboot, or alter boot ordering.
# Repeat: Reuses repository fixtures and writes a fresh optional evidence report per run; numbers vary with governor, cooling, and load.
# Recovery: Remove only cached evidence/temp files; run on an otherwise idle board and record the governor for comparability.
# Outputs: Per-file hw/sw wall seconds, CPU seconds, fps, speedup ratio, and PASS status.
# Verification: Both paths must complete with matching frame counts; figures are informational and PASS on completion, not on a fixed bar.
# Documentation: docs/optional/vpu.md
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

MEDIA_DIR="$REPO_ROOT/testdata/videos"
OUTPUT=""
MODE=pair
ONLY=""
while (($#)); do
    case "$1" in
        --media-dir) MEDIA_DIR=${2:?}; shift 2 ;;
        --output) OUTPUT=${2:?}; shift 2 ;;
        --all) MODE=all; shift ;;
        --only) ONLY=${2:?}; shift 2 ;;
        -h|--help)
            echo "Usage: sudo $0 [--media-dir DIR] [--output FILE] [--all] [--only BASENAME]"
            exit 0
            ;;
        *) die "Unknown argument: $1" ;;
    esac
done

[[ -f /etc/cedarc.conf ]] || die "/etc/cedarc.conf is missing; reinstall the VPU userspace (sudo make board-vpu-install)"
require_command gst-launch-1.0
require_command gst-inspect-1.0
require_command ffmpeg
require_command ffprobe
gst-inspect-1.0 h264parse >/dev/null || die "gstreamer1.0-plugins-bad h264parse is required"
gst-inspect-1.0 h265parse >/dev/null || die "gstreamer1.0-plugins-bad h265parse is required"
gst-inspect-1.0 omxh264dec >/dev/null || die "OMX H.264 decoder is not registered"
gst-inspect-1.0 omxhevcvideodec >/dev/null || die "OMX H.265 decoder is not registered"

if [[ -n $ONLY ]]; then
    mapfile -t FILES < <(printf '%s\n' "$MEDIA_DIR/$ONLY.mp4" "$MEDIA_DIR/$ONLY")
else
    case "$MODE" in
        pair)
            FILES=(
                "$MEDIA_DIR/mandelbrot-h264-720p-30fps.mp4"
                "$MEDIA_DIR/mandelbrot-h265-720p-30fps.mp4"
            )
            ;;
        all)
            mapfile -t FILES < <(find "$MEDIA_DIR" -maxdepth 1 -name '*.mp4' -print | sort)
            ;;
    esac
fi
((${#FILES[@]})) || die "No fixtures selected in $MEDIA_DIR"
for file in "${FILES[@]}"; do
    [[ -s $file ]] || die "Missing fixture: $file; run 'sudo make board-vpu-generate-decode-videos' (pair) or 'sudo make board-vpu-generate-videos' (full set)"
done

WORK=$(mktemp -d /var/tmp/zero3w-vpu-speed.XXXXXXXX)
trap 'rm -rf -- "$WORK"' EXIT
preserve_work() {
    printf 'Failure debug files preserved in %s\n' "$WORK" >&2
    trap - EXIT
}

now() { date +%s.%N; }
elapsed() { awk -v s="$1" -v e="$2" 'BEGIN { printf "%.2f", e - s }'; }
fps() { awk -v n="$1" -v s="$2" 'BEGIN { printf "%.1f", (s + 0 > 0) ? n / s : 0 }'; }
ratio() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.2f", (b + 0 > 0) ? a / b : 0 }'; }
# Total reaped-children user+sys CPU seconds; diff two snapshots to isolate one
# pipeline without any extra dependency. The probing awk itself is negligible.
cpu_children() {
    times | awk 'NR==2 { split($1, a, "m"); split($2, b, "m"); sub(/s$/, "", a[2]); sub(/s$/, "", b[2]); printf "%.2f", a[1]*60+a[2]+b[1]*60+b[2] }'
}
cpu_used() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.2f", b - a }'; }

time_one() {
    local file=$1 base codec width height parser decoder
    base=$(basename "$file" .mp4)
    mapfile -t info < <(ffprobe -v error -select_streams v:0 \
        -show_entries stream=codec_name,width,height \
        -of default=noprint_wrappers=1:nokey=1 "$file")
    codec=${info[0]:-}
    width=${info[1]:-}
    height=${info[2]:-}
    [[ $width =~ ^[0-9]+$ && $height =~ ^[0-9]+$ ]] || die "$base: cannot probe dimensions"
    case "$codec" in
        h264) parser=h264parse; decoder=omxh264dec ;;
        hevc) parser=h265parse; decoder=omxhevcvideodec ;;
        *) die "$base: unsupported codec '$codec'" ;;
    esac

    local hw_raw="$WORK/$base-hw.yuv" sw_raw="$WORK/$base-sw.yuv" hw_log="$WORK/$base-hw.log"
    local frames frame_size sw_size sw_start sw_end sw_sec sw_fps sw_cpu hw_start hw_end hw_sec hw_fps hw_cpu speed
    local cpu_mark
    printf 'Timing %s (%s %sx%s)\n' "$base" "$codec" "$width" "$height"

    cpu_mark=$(cpu_children)
    sw_start=$(now)
    if ! timeout 300s ffmpeg -nostdin -hide_banner -loglevel error -y -i "$file" \
        -pix_fmt yuv420p -f rawvideo "$sw_raw" 2>/dev/null; then
        preserve_work
        die "$base software decode failed"
    fi
    sw_end=$(now)
    sw_cpu=$(cpu_used "$cpu_mark" "$(cpu_children)")
    frame_size=$((width * height * 3 / 2))
    sw_size=$(stat -c %s "$sw_raw")
    ((sw_size > 0 && sw_size % frame_size == 0)) || { preserve_work; die "$base software dump has unexpected size $sw_size"; }
    frames=$((sw_size / frame_size))
    sw_sec=$(elapsed "$sw_start" "$sw_end")
    sw_fps=$(fps "$frames" "$sw_sec")

    cpu_mark=$(cpu_children)
    hw_start=$(now)
    if ! GST_DEBUG=2 timeout 300s gst-launch-1.0 \
        filesrc "location=$file" ! qtdemux ! "$parser" ! "$decoder" ! \
        videoconvert ! 'video/x-raw,format=I420' ! filesink "location=$hw_raw" sync=false >"$hw_log" 2>&1; then
        cat "$hw_log" >&2
        preserve_work
        die "$base hardware decode failed"
    fi
    hw_end=$(now)
    hw_cpu=$(cpu_used "$cpu_mark" "$(cpu_children)")
    grep -q 'open /dev/cedar_dev' "$hw_log" || { preserve_work; die "$base decode did not open Cedar"; }
    grep -q 'Got EOS' "$hw_log" || { preserve_work; die "$base decode did not reach EOS"; }
    hw_sec=$(elapsed "$hw_start" "$hw_end")
    hw_fps=$(fps "$frames" "$hw_sec")
    speed=$(ratio "$hw_fps" "$sw_fps")
    printf 'PASS: %s frames=%d hw=%.2fs (cpu %ss, %s fps) sw=%.2fs (cpu %ss, %s fps) speedup=%sx\n' \
        "$base" "$frames" "$hw_sec" "$hw_cpu" "$hw_fps" "$sw_sec" "$sw_cpu" "$sw_fps" "$speed"
    rm -f -- "$hw_raw" "$sw_raw"

    if [[ -n $OUTPUT ]]; then
        {
            echo "file=$base.mp4"
            echo "codec=$codec width=$width height=$height frames=$frames"
            echo "hw_sec=$hw_sec hw_cpu=$hw_cpu hw_fps=$hw_fps sw_sec=$sw_sec sw_cpu=$sw_cpu sw_fps=$sw_fps speedup=$speed result=PASS"
        } >> "$OUTPUT.tmp"
    fi
}

if [[ -n $OUTPUT ]]; then
    install -d -m 755 "$(dirname "$OUTPUT")"
    {
        echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "uname=$(uname -a)"
        echo "kernel=$(uname -r)"
        echo "nproc=$(nproc)"
        echo "governor=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || echo unknown)"
        echo "cedarc_conf=$(sha256sum /etc/cedarc.conf)"
    } > "$OUTPUT.tmp"
fi

for file in "${FILES[@]}"; do
    time_one "$file"
done

if [[ -n $OUTPUT ]]; then
    mv -- "$OUTPUT.tmp" "$OUTPUT"
    printf 'Evidence saved to %s\n' "$OUTPUT"
fi
