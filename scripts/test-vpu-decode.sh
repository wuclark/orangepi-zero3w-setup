#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
require_root

MEDIA_DIR=/var/lib/orangepi-zero3w-setup/vpu-test-media
OUTPUT=""
while (($#)); do
    case "$1" in
        --media-dir) MEDIA_DIR=${2:?}; shift 2 ;;
        --output) OUTPUT=${2:?}; shift 2 ;;
        -h|--help)
            echo "Usage: sudo $0 [--media-dir DIR] [--output FILE]"
            exit 0
            ;;
        *) die "Unknown argument: $1" ;;
    esac
done

H264_URL=https://test-videos.co.uk/vids/jellyfish/mp4/h264/720/Jellyfish_720_10s_1MB.mp4
H265_URL=https://test-videos.co.uk/vids/bigbuckbunny/mp4/h265/720/Big_Buck_Bunny_720_10s_5MB.mp4
H264_FILE="$MEDIA_DIR/jellyfish-h264.mp4"
H265_FILE="$MEDIA_DIR/bigbuckbunny-h265.mp4"
WORK=$(mktemp -d -t zero3w-vpu-test.XXXXXXXX)
trap 'rm -rf -- "$WORK"' EXIT

install -d -m 755 "$MEDIA_DIR"
[[ -f /etc/cedarc.conf ]] || die "/etc/cedarc.conf is missing; reinstall the VPU userspace"
command -v curl >/dev/null || die "curl is required to download VPU test media"
command -v gst-launch-1.0 >/dev/null || die "gstreamer1.0-tools is required"
gst-inspect-1.0 h264parse >/dev/null || die "gstreamer1.0-plugins-bad h264parse is required"
gst-inspect-1.0 h265parse >/dev/null || die "gstreamer1.0-plugins-bad h265parse is required"
gst-inspect-1.0 omxh264dec >/dev/null || die "OMX H.264 decoder is not registered"
gst-inspect-1.0 omxhevcvideodec >/dev/null || die "OMX H.265 decoder is not registered"

download() {
    local url=$1 file=$2
    if [[ ! -s $file ]]; then
        printf 'Downloading %s\n' "$(basename "$file")"
        curl --fail --location --retry 3 --output "$file" "$url"
    fi
    [[ -s $file ]] || die "Downloaded file is empty: $file"
}

run_decode() {
    local label=$1 file=$2 decoder=$3 parser=$4 log=$5
    printf 'Testing hardware %s decode\n' "$label"
    if GST_DEBUG=2 timeout 90s gst-launch-1.0 -v \
        filesrc "location=$file" ! qtdemux ! "$parser" ! "$decoder" ! \
        fakesink sync=false >"$log" 2>&1; then
        grep -q 'open /dev/cedar_dev' "$log" || die "$label decode did not open Cedar"
        grep -q 'Got EOS' "$log" || die "$label decode did not reach EOS"
        printf 'PASS: %s hardware decode\n' "$label"
    else
        cat "$log" >&2
        die "$label hardware decode failed"
    fi
}

download "$H264_URL" "$H264_FILE"
download "$H265_URL" "$H265_FILE"
run_decode H264 "$H264_FILE" omxh264dec h264parse "$WORK/h264.log"
run_decode H265 "$H265_FILE" omxhevcvideodec h265parse "$WORK/h265.log"

if [[ -n $OUTPUT ]]; then
    install -d -m 755 "$(dirname "$OUTPUT")"
    {
        echo "cedarc_conf=$(sha256sum /etc/cedarc.conf)"
        echo "h264_file=$(sha256sum "$H264_FILE")"
        echo "h264_url=$H264_URL"
        echo "h265_file=$(sha256sum "$H265_FILE")"
        echo "h265_url=$H265_URL"
        echo "h264_result=PASS"
        echo "h265_result=PASS"
        echo "h264_log="; cat "$WORK/h264.log"
        echo "h265_log="; cat "$WORK/h265.log"
    } > "$OUTPUT"
    printf 'Evidence saved to %s\n' "$OUTPUT"
fi
