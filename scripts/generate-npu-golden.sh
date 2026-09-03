#!/usr/bin/env bash
# Purpose: Generate a real NPU golden (NBG + input + ACUITY host reference
#          tensor) for a named SDK model, using the ACUITY/Pegasus
#          quantization toolchain, not a plain independent CPU run.
# Platform: Linux/WSL2 host with Docker; requires a host clone of
#          https://github.com/wuclark/a733_npu_driver (its Docker image
#          carries the real ACUITY toolkit; see its docs/01-setup-host.md).
# Inputs: --model {lenet,yolov5,resnet50}, --sdk-tarball (work/images/ai-sdk.tar.gz),
#          --driver-repo (host checkout of a733_npu_driver), --output (tarball path).
#          resnet50 additionally requires --public-onnx (a separately obtained,
#          openly licensed ResNet50 ONNX file; the SDK ships no resnet50 source).
# Writes: one generated, git-ignored archive under work/vendor-output or an
#          explicit --output path. Never writes into the git tree.
# Safety: validates archive member paths; runs ACUITY only inside the driver
#          repo's own Docker image, never installs anything on the host.
# Repeat behavior: refuses to overwrite; remove only a verified failed output.
# Provenance: NBG/input come from the AI SDK archive (lenet, yolov5s-sim) or a
#          user-supplied public ONNX (resnet50); the golden tensor is produced
#          by ACUITY's own host (CPU) quantized inference, matching the exact
#          quantization run used to export the NBG.
# Why not a plain CPU run: vpm_run's [golden] check is a raw memcmp(); only a
#          golden produced by the *same* ACUITY quantization run as the NBG
#          has any chance of matching. See docs/optional/npu.md.
# Recovery: preserve inputs and rerun with a new --output path.
# Verification: run board-npu-model-test.sh on real board hardware; this
#          script only produces host-side evidence.
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

MODEL=""; SDK_TARBALL=""; DRIVER_REPO=""; OUTPUT=""; PUBLIC_ONNX=""
ONNX_INPUTS=""; ONNX_INPUT_SIZE_LIST=""; ONNX_OUTPUTS=""
IMAGE=${NPU_ACUITY_IMAGE:-ubuntu-npu:v2.0.10.1}
TARGET=${NPU_ACUITY_TARGET:-VIP9000NANODI_PLUS_PID0X1000003B}

usage() {
    cat <<'EOF'
Usage: scripts/generate-npu-golden.sh --model {lenet,yolov5,resnet50} \
    --sdk-tarball FILE --driver-repo DIR --output FILE [--public-onnx FILE]

  --model lenet      Caffe LeNet from ai-sdk/models/lenet (uint8 + int16).
  --model yolov5      ONNX yolov5s-sim from ai-sdk/models/yolov5s-sim; this is
                       an architecture-level reference, not proven identical
                       to the bundled examples/yolov5/model/v3/yolov5.nb.
  --model resnet50     Builds a NEW resnet50 NBG+golden from a public,
                       openly licensed ResNet50 ONNX file (--public-onnx);
                       the SDK ships no source weights for its own
                       resnet50.nb, so there is nothing to regenerate a
                       golden for.

  --driver-repo DIR   Host checkout of wuclark/a733_npu_driver. Its Docker
                       image must already be built per that repo's
                       docs/01-setup-host.md; this script does not build it.
  --output FILE       Destination tarball; must not already exist.
  --inputs NAMES / --input-size-list SIZES / --outputs NAMES
                       Override ACUITY's ONNX graph input/output node names
                       and input size list for --model yolov5/resnet50. The
                       built-in defaults are best-effort starting points
                       (yolov5s-sim: inputs=images, 640,640,3, outputs=output;
                       resnet50: inputs=input, 224,224,3, outputs=output) and
                       have NOT been run end-to-end; inspect the real ONNX
                       graph first, e.g.:
                         python3 -c "import onnx; m=onnx.load('MODEL.onnx'); \
                           print([i.name for i in m.graph.input], \
                                 [o.name for o in m.graph.output])"
                       and pass corrected values here if they differ.

Environment:
  NPU_ACUITY_IMAGE     Docker image tag (default: ubuntu-npu:v2.0.10.1)
  NPU_ACUITY_TARGET     ACUITY optimize target (default:
                         VIP9000NANODI_PLUS_PID0X1000003B, matches the A733
                         VIP9000 core on this board)
EOF
}

while (($#)); do
    case "$1" in
        --model) MODEL=${2:?}; shift 2;;
        --sdk-tarball) SDK_TARBALL=${2:?}; shift 2;;
        --driver-repo) DRIVER_REPO=${2:?}; shift 2;;
        --output) OUTPUT=${2:?}; shift 2;;
        --public-onnx) PUBLIC_ONNX=${2:?}; shift 2;;
        --inputs) ONNX_INPUTS=${2:?}; shift 2;;
        --input-size-list) ONNX_INPUT_SIZE_LIST=${2:?}; shift 2;;
        --outputs) ONNX_OUTPUTS=${2:?}; shift 2;;
        -h|--help) usage; exit 0;;
        *) die "Unknown argument: $1";;
    esac
done

case "$MODEL" in
    lenet|yolov5|resnet50) ;;
    "") die "Missing --model {lenet,yolov5,resnet50}";;
    *) die "Unknown --model: $MODEL (expected lenet, yolov5, or resnet50)";;
esac
[[ -f $SDK_TARBALL ]] || die "AI SDK archive not found: $SDK_TARBALL"
[[ -d $DRIVER_REPO ]] || die "a733_npu_driver checkout not found: $DRIVER_REPO"
[[ -n $OUTPUT && ! -e $OUTPUT ]] || die "Output is missing or already exists: $OUTPUT"
require_command docker
docker image inspect "$IMAGE" >/dev/null 2>&1 || \
    die "ACUITY Docker image not found: $IMAGE (build it per a733_npu_driver's docs/01-setup-host.md)"
[[ $MODEL != resnet50 || -f $PUBLIC_ONNX ]] || \
    die "--model resnet50 requires --public-onnx FILE (an openly licensed ResNet50 ONNX file)"
if [[ $MODEL != lenet ]]; then
    ai_sdk_scripts="$DRIVER_REPO/work/ai-sdk/ZIFENG278-ai-sdk/scripts"
    [[ -f $ai_sdk_scripts/pegasus_setup.sh ]] || \
        die "driver repo is missing its own AI SDK checkout: $ai_sdk_scripts/pegasus_setup.sh (follow a733_npu_driver's docs/01-setup-host.md first)"
fi

work=$(mktemp -d -t zero3w-npu-acuity.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
log "Working directory: $work"

python3 - "$SDK_TARBALL" <<'PY'
import pathlib, sys, tarfile
with tarfile.open(sys.argv[1], "r:gz") as tf:
    for member in tf:
        name = pathlib.PurePosixPath(member.name)
        if name.is_absolute() or ".." in name.parts:
            raise SystemExit(f"unsafe archive member: {member.name}")
PY

package_dir="$work/package"
install -d -m 755 "$package_dir"

case "$MODEL" in
lenet)
    # Recipe matches wuclark/a733_npu_driver reports/g2-acuity-lenet.md,
    # already board-validated (uint8 + int16) on a real A733 VIP9000 board.
    log "Extracting lenet Caffe source from the AI SDK archive"
    tar -xzf "$SDK_TARBALL" -C "$work" \
        ai-sdk/models/lenet/lenet.prototxt ai-sdk/models/lenet/lenet.caffemodel \
        ai-sdk/models/lenet/channel_mean_value.txt ai-sdk/models/lenet/dataset.txt \
        ai-sdk/models/lenet/input_image
    model_src="$work/ai-sdk/models/lenet"
    log "Running ACUITY import/quantize/inference/export for lenet (int16) in Docker"
    docker run --rm -v "$model_src:/work/lenet" -w /work \
        -e ACUITY_PATH=/root/acuity-toolkit-whl-6.30.22/bin \
        -e VIV_SDK=/root/Vivante_IDE/VivanteIDE5.11.0/cmdtools \
        "$IMAGE" bash -lc '
            set -Eeuo pipefail
            export PATH="$ACUITY_PATH:$PATH"
            cd /work
            pegasus_one lenet
            ../scripts/pegasus_quantize.sh lenet int16
            ../scripts/pegasus_inference.sh lenet int16
            ../scripts/pegasus_export_ovx.sh lenet int16
        '
    log "Packaging ACUITY outputs for board deployment"
    python3 "$DRIVER_REPO/scripts/host/package_acuity_nbg.py" \
        --model-dir "$model_src" --package-dir "$package_dir" --quant int16
    ;;
yolov5|resnet50)
    if [[ $MODEL == yolov5 ]]; then
        log "Extracting yolov5s-sim ONNX source from the AI SDK archive"
        tar -xzf "$SDK_TARBALL" -C "$work" ai-sdk/models/yolov5s-sim
        onnx_path="$work/ai-sdk/models/yolov5s-sim/yolov5s-sim.onnx"
        dataset_path="$work/ai-sdk/models/yolov5s-sim/dataset.txt"
        name=yolov5s_sim
        inputs=${ONNX_INPUTS:-images}
        input_size_list=${ONNX_INPUT_SIZE_LIST:-640,640,3}
        outputs=${ONNX_OUTPUTS:-output}
    else
        log "Using supplied public ResNet50 ONNX: $PUBLIC_ONNX"
        install -d -m 755 "$work/resnet50-public"
        cp -a "$PUBLIC_ONNX" "$work/resnet50-public/resnet50.onnx"
        printf 'resnet50.onnx\n' > "$work/resnet50-public/dataset.txt"
        onnx_path="$work/resnet50-public/resnet50.onnx"
        dataset_path="$work/resnet50-public/dataset.txt"
        name=resnet50_public
        inputs=${ONNX_INPUTS:-input}
        input_size_list=${ONNX_INPUT_SIZE_LIST:-224,224,3}
        outputs=${ONNX_OUTPUTS:-output}
    fi
    log "Running ACUITY ONNX conversion for $name (int16) via a733_npu_driver's flow"
    "$DRIVER_REPO/scripts/host/convert_onnx_to_nbg.sh" \
        --name "$name" --onnx "$onnx_path" --dataset "$dataset_path" \
        --quant int16 --inputs "$inputs" --input-size-list "$input_size_list" \
        --outputs "$outputs" --image "$IMAGE" --target "$TARGET" \
        --package-root "$work/model-packages"
    cp -a "$work/model-packages/$name/int16/." "$package_dir/"
    ;;
esac

[[ -f $package_dir/network_binary.nb ]] || die "ACUITY did not produce network_binary.nb"
[[ -f $package_dir/host_output_0.txt ]] || die "ACUITY did not produce a host golden tensor (host_output_0.txt)"
install -d -m 755 "$(dirname "$OUTPUT")"
tar -C "$package_dir" --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 \
    --numeric-owner -czf "$OUTPUT" .
printf 'Created private NPU golden (%s): %s\n' "$MODEL" "$OUTPUT"
printf 'This archive is proprietary/derived-vendor content: keep it out of git.\n'
