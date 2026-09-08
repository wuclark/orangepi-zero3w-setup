#!/usr/bin/env bash
# Purpose: Compare Cedar hardware decode against software decode with PSNR/SSIM.
# Platform: Orange Pi Zero 3W target board with VPU userspace and GStreamer installed.
# Inputs: Optional --output FILE, --media-dir DIR, --all for the full fixture set, --only BASENAME.
# Dependencies: Bash, root, GStreamer OMX decoders, ffmpeg/ffprobe with psnr and ssim filters, /etc/cedarc.conf.
# Writes: Raw yuv420p dumps in a private temp dir under /var/tmp (1080p60
#          intermediates exceed 5 GB and do not fit the board's tmpfs /tmp)
#          and optional timestamped quality evidence at OUTPUT.
# Safety: Headless decode and offline comparison only; does not present video, install packages, reboot, or alter boot ordering.
# Repeat: Reuses repository fixtures and writes a fresh optional evidence report per run.
# Recovery: Remove only cached evidence/temp files; restore VPU configuration through the recovery guide if needed.
# Outputs: Per-file frame counts, PSNR/SSIM averages, and PASS/FAIL status.
# Verification: Require every selected file to produce matching frame counts plus measurable PSNR/SSIM; reference board 2026-09-08 gives 17/17 bit-identical (psnr inf, ssim 1.0) and thresholds remain report-only.
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
ffmpeg -hide_banner -h filter=psnr >/dev/null 2>&1 || die "ffmpeg psnr filter is unavailable; reinstall ffmpeg"
ffmpeg -hide_banner -h filter=ssim >/dev/null 2>&1 || die "ffmpeg ssim filter is unavailable; reinstall ffmpeg"

if [[ -n $ONLY ]]; then
    case "$ONLY" in
        *.mp4) FILES=("$MEDIA_DIR/$ONLY") ;;
        *) FILES=("$MEDIA_DIR/$ONLY.mp4") ;;
    esac
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

WORK=$(mktemp -d /var/tmp/zero3w-vpu-quality.XXXXXXXX)
trap 'rm -rf -- "$WORK"' EXIT
preserve_work() {
    printf 'Failure debug files preserved in %s\n' "$WORK" >&2
    trap - EXIT
}

probe() {
    ffprobe -v error -select_streams v:0 \
        -show_entries stream=codec_name,width,height,avg_frame_rate \
        -of default=noprint_wrappers=1:nokey=1 "$1"
}

compare_one() {
    local file=$1 base label codec width height fps parser decoder
    base=$(basename "$file" .mp4)
    mapfile -t info < <(probe "$file")
    codec=${info[0]:-}
    width=${info[1]:-}
    height=${info[2]:-}
    fps=$(awk -F/ '{if ($2+0 > 0) printf "%d", ($1+0)/($2+0); else print $1}' <<<"${info[3]:-0}")
    [[ $width =~ ^[0-9]+$ && $height =~ ^[0-9]+$ ]] || die "$base: cannot probe dimensions"
    case "$codec" in
        h264) parser=h264parse; decoder=omxh264dec; label=H264 ;;
        hevc) parser=h265parse; decoder=omxhevcvideodec; label=H265 ;;
        *) die "$base: unsupported codec '$codec'" ;;
    esac

    local hw_raw="$WORK/$base-hw.yuv" sw_raw="$WORK/$base-sw.yuv"
    local hw_log="$WORK/$base-hw.log" sw_log="$WORK/$base-sw.log"
    printf 'Testing %s (%s %sx%s)\n' "$base" "$label" "$width" "$height"

    # Cedar pads decoded dimensions to its alignment (e.g. height 720 -> 736),
    # so dump the hardware output as-is and crop the padding off below.
    # Cropping keeps a pixel-exact comparison; rescaling would inject error.
    local hw_padded="$WORK/$base-hw-padded.yuv"
    if ! GST_DEBUG=2 timeout 120s gst-launch-1.0 \
        filesrc "location=$file" ! qtdemux ! "$parser" ! "$decoder" ! \
        videoconvert ! 'video/x-raw,format=I420' ! filesink "location=$hw_padded" sync=false >"$hw_log" 2>&1; then
        cat "$hw_log" >&2
        die "$base hardware decode failed"
    fi
    grep -q 'open /dev/cedar_dev' "$hw_log" || die "$base decode did not open Cedar"
    grep -q 'Got EOS' "$hw_log" || die "$base decode did not reach EOS"

    local sw_rc=0
    timeout 120s ffmpeg -nostdin -hide_banner -loglevel error -y -i "$file" \
        -pix_fmt yuv420p -f rawvideo "$sw_raw" >"$sw_log" 2>&1 || sw_rc=$?
    if ((sw_rc != 0)); then
        printf 'ffmpeg software-decode exit=%d log:\n' "$sw_rc" >&2
        cat "$sw_log" >&2
        preserve_work
        die "$base software decode failed (ffmpeg exit=$sw_rc)"
    fi

    local frame_size sw_size sw_frames hw_padded_size padded_frame padded_height crop_log crop_rc
    frame_size=$((width * height * 3 / 2))
    sw_size=$(stat -c %s "$sw_raw")
    ((sw_size > 0)) || die "$base produced an empty software dump"
    ((sw_size % frame_size == 0)) || die "$base sw dump size $sw_size is not a multiple of frame size $frame_size"
    sw_frames=$((sw_size / frame_size))
    hw_padded_size=$(stat -c %s "$hw_padded")
    ((hw_padded_size > 0)) || die "$base produced an empty hardware dump"
    ((hw_padded_size % sw_frames == 0)) || die "$base hw dump size $hw_padded_size is not a multiple of sw frame count $sw_frames"
    padded_frame=$((hw_padded_size / sw_frames))
    ((padded_frame * 2 % (3 * width) == 0)) || die "$base padded frame $padded_frame does not match width $width (stride padding?)"
    padded_height=$((padded_frame * 2 / (3 * width)))
    ((padded_height >= height)) || die "$base padded height $padded_height is smaller than probed height $height"
    crop_log="$WORK/$base-crop.log"; crop_rc=0
    timeout 120s ffmpeg -nostdin -hide_banner -loglevel error -y \
        -f rawvideo -s "${width}x${padded_height}" -pix_fmt yuv420p -i "$hw_padded" \
        -vf "crop=${width}:${height}:0:0" -pix_fmt yuv420p -f rawvideo "$hw_raw" \
        >"$crop_log" 2>&1 || crop_rc=$?
    if ((crop_rc != 0)); then
        printf 'ffmpeg crop exit=%d log:\n' "$crop_rc" >&2
        cat "$crop_log" >&2
        preserve_work
        die "$base padding crop failed (ffmpeg exit=$crop_rc)"
    fi
    hw_frames=$sw_frames

    local cmp_rc=0 psnr ssim
    local psnr_log="$WORK/$base-psnr.log" ssim_log="$WORK/$base-ssim.log"
    timeout 120s ffmpeg -nostdin -hide_banner -f rawvideo -s "${width}x${height}" -pix_fmt yuv420p -i "$hw_raw" \
        -f rawvideo -s "${width}x${height}" -pix_fmt yuv420p -i "$sw_raw" \
        -lavfi psnr -f null - >"$psnr_log" 2>&1 || cmp_rc=$?
    timeout 120s ffmpeg -nostdin -hide_banner -f rawvideo -s "${width}x${height}" -pix_fmt yuv420p -i "$hw_raw" \
        -f rawvideo -s "${width}x${height}" -pix_fmt yuv420p -i "$sw_raw" \
        -lavfi ssim -f null - >"$ssim_log" 2>&1 || cmp_rc=$?
    if ((cmp_rc != 0)); then
        printf 'ffmpeg compare exit=%d logs:\n' "$cmp_rc" >&2
        cat "$psnr_log" "$ssim_log" >&2
        preserve_work
        die "$base PSNR/SSIM comparison failed (ffmpeg exit=$cmp_rc)"
    fi
    # Identical decodes report average:inf / All:1.0 — accept inf as a value.
    psnr=$(grep -oE 'average:(inf|[0-9.]+)' "$psnr_log" | tail -n 1 | cut -d: -f2)
    ssim=$(grep -oE 'All:(inf|[0-9.]+)' "$ssim_log" | tail -n 1 | cut -d: -f2)
    [[ -n $psnr && -n $ssim ]] || { cat "$psnr_log" "$ssim_log" >&2; preserve_work; die "$base could not parse PSNR/SSIM from comparison output"; }
    printf 'PASS: %s frames=%d psnr_avg=%s ssim_all=%s\n' "$base" "$hw_frames" "$psnr" "$ssim"
    rm -f -- "$hw_raw" "$sw_raw" "$hw_padded"

    if [[ -n $OUTPUT ]]; then
        {
            echo "file=$base.mp4"
            echo "file_sha256=$(sha256sum "$file")"
            echo "codec=$codec width=$width height=$height fps=$fps"
            echo "padded=${width}x${padded_height} crop=0,0"
            echo "hw_frames=$hw_frames sw_frames=$sw_frames"
            echo "psnr_avg=$psnr ssim_all=$ssim result=PASS"
        } >> "$OUTPUT.tmp"
    fi
}

if [[ -n $OUTPUT ]]; then
    install -d -m 755 "$(dirname "$OUTPUT")"
    {
        echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "uname=$(uname -a)"
        echo "kernel=$(uname -r)"
        echo "cedarc_conf=$(sha256sum /etc/cedarc.conf)"
        echo "ffmpeg=$(ffmpeg -hide_banner -version 2>/dev/null | head -n 1)"
    } > "$OUTPUT.tmp"
fi

for file in "${FILES[@]}"; do
    compare_one "$file"
done

if [[ -n $OUTPUT ]]; then
    mv -- "$OUTPUT.tmp" "$OUTPUT"
    printf 'Evidence saved to %s\n' "$OUTPUT"
fi
