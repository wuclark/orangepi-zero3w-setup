#!/usr/bin/env bash
# Purpose: Generate synthetic H.264/H.265 video fixtures for VPU decode tests.
# Platform: Host with FFmpeg; generated media is local test input, not support evidence by itself.
# Inputs: Optional --only, --decode-pair, and --force generation options.
# Dependencies: Bash, ffmpeg, ffprobe, and writable repository testdata/videos.
# Writes: MP4 and framemd5 files under testdata/videos; --force permits replacement.
# Safety: Generates local reproducible fixtures only; never installs software or touches board state.
# Repeat: Reuses existing files by default and replaces them only with --force.
# Recovery: Remove generated testdata/videos files and regenerate from the same command.
# Outputs: Synthetic video fixtures, hashes, and FFmpeg/FFprobe diagnostics.
# Verification: Confirm generated files have expected codec metadata and matching framemd5 output.
# Documentation: docs/optional/vpu.md
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
OUTPUT_DIR="$REPO_ROOT/testdata/videos"
ONLY=""
FORCE=no
DECODE_PAIR=no

usage() {
    cat <<'EOF'
Usage: ./scripts/gen_test_videos.sh [options]

Generate synthetic H.264/H.265 VPU test videos under testdata/videos/.

Options:
  --only SOURCE  Generate one source or combo: mandelbrot, testsrc, rgbtestsrc,
                 life, or combo
  --decode-pair  Generate only the 720p H.264/H.265 files used by decode tests
  --force        Overwrite existing MP4 and framemd5 files
  -h, --help     Show this help
EOF
}

while (($#)); do
    case "$1" in
        --only) ONLY=${2:?missing source after --only}; shift 2 ;;
        --decode-pair) DECODE_PAIR=yes; shift ;;
        --force) FORCE=yes; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

command -v ffmpeg >/dev/null 2>&1 || {
    echo 'ERROR: ffmpeg is required. Install it with: sudo apt install ffmpeg' >&2
    exit 1
}
command -v ffprobe >/dev/null 2>&1 || {
    echo 'ERROR: ffprobe is required. It is normally provided by the ffmpeg package.' >&2
    exit 1
}

SOURCES=(
    'mandelbrot:mandelbrot'
    'testsrc:testsrc'
    'rgbtestsrc:rgbtestsrc'
    'life:life'
)

if [[ -n $ONLY ]]; then
    case "$ONLY" in
        mandelbrot|testsrc|rgbtestsrc|life|combo) ;;
        *) echo "ERROR: unsupported source '$ONLY'" >&2; exit 2 ;;
    esac
fi
[[ -z $ONLY || $DECODE_PAIR == no ]] || {
    echo 'ERROR: --decode-pair cannot be combined with --only' >&2
    exit 2
}

mkdir -p "$OUTPUT_DIR"

OVERLAY="drawtext=text='%{n}':x=10:y=10:fontsize=48:fontcolor=white:box=1:boxcolor=black@0.7,drawtext=text='%{pts\\:hms}':x=10:y=70:fontsize=32:fontcolor=yellow:box=1:boxcolor=black@0.7"
GENERATED=()

generate_file() {
    local name=$1 input=$2 codec=$3 profile=$4 fps=$5
    local output="$OUTPUT_DIR/$name.mp4" checksum="$OUTPUT_DIR/$name.md5"
    if [[ -s $output && $FORCE != yes ]]; then
        echo "Skipping existing $output"
    else
        echo "Generating $output"
        if [[ $codec == h264 ]]; then
            ffmpeg -hide_banner -loglevel error -y \
                -f lavfi -i "$input" -t 10 -vf "$OVERLAY" \
                -c:v libx264 -pix_fmt yuv420p -profile:v "$profile" \
                -g "$fps" -keyint_min "$fps" -sc_threshold 0 -movflags +faststart \
                "$output"
        else
            ffmpeg -hide_banner -loglevel error -y \
                -f lavfi -i "$input" -t 10 -vf "$OVERLAY" \
                -c:v libx265 -pix_fmt yuv420p -tag:v hvc1 \
                -x265-params "keyint=$fps:min-keyint=$fps:scenecut=0" \
                -movflags +faststart "$output"
        fi
    fi
    if [[ ! -s $checksum || $FORCE == yes ]]; then
        echo "Generating $checksum"
        ffmpeg -hide_banner -loglevel error -i "$output" -f framemd5 "$checksum"
    fi
    GENERATED+=("$output")
}

if [[ $DECODE_PAIR == yes ]]; then
    generate_file 'mandelbrot-h264-720p-30fps' \
        'mandelbrot=s=1280x720:r=30' h264 main 30
    generate_file 'mandelbrot-h265-720p-30fps' \
        'mandelbrot=s=1280x720:r=30' h265 main 30
fi

for source_pair in "${SOURCES[@]}"; do
    [[ $DECODE_PAIR == yes ]] && continue
    source=${source_pair%%:*}
    extra_filter=${source_pair#*:}
    [[ -z $ONLY || $ONLY == "$source" ]] || continue
    for geometry in '1280x720:30:720p:main' '1920x1080:60:1080p:high'; do
        IFS=: read -r resolution fps res_label profile <<< "$geometry"
        for codec in h264 h265; do
            generate_file "$source-$codec-$res_label-${fps}fps" \
                "$extra_filter=s=$resolution:r=$fps" "$codec" "$profile" "$fps"
        done
    done
done

if [[ -z $ONLY || $ONLY == combo ]]; then
    combo="$OUTPUT_DIR/combo-h264-720p-30fps.mp4"
    combo_md5="${combo%.mp4}.md5"
    if [[ -s $combo && $FORCE != yes ]]; then
        echo "Skipping existing $combo"
    else
        echo "Generating $combo"
        ffmpeg -hide_banner -loglevel error -y \
            -f lavfi -i 'testsrc=s=640x720:r=30' \
            -f lavfi -i 'mandelbrot=s=640x720:r=30' -t 10 \
            -filter_complex "[0:v][1:v]hstack=inputs=2,$OVERLAY" \
            -c:v libx264 -pix_fmt yuv420p -profile:v main -g 30 \
            -keyint_min 30 -sc_threshold 0 -movflags +faststart "$combo"
    fi
    if [[ ! -s $combo_md5 || $FORCE == yes ]]; then
        echo "Generating $combo_md5"
        ffmpeg -hide_banner -loglevel error -i "$combo" -f framemd5 "$combo_md5"
    fi
    GENERATED+=("$combo")
fi

printf '\n%-48s %-10s %s\n' 'FILE' 'SIZE' 'DURATION'
printf '%-48s %-10s %s\n' '----' '----' '--------'
for file in "${GENERATED[@]}"; do
    size=$(du -h "$file" | awk '{print $1}')
    duration=$(ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$file")
    printf '%-48s %-10s %ss\n' "$(basename "$file")" "$size" "$duration"
done
