#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
LAYER=""; ACTION=""; LOG="/var/log/orangepi-zero3w-setup/acceleration-progress.log"; YES=no

usage() {
    cat <<'EOF'
Usage: sudo ./scripts/board-acceleration-workflow.sh --layer LAYER --action ACTION [options]

LAYER:  gpu | vpu | npu
ACTION: precheck | install | verify

Options:
  --log FILE   Append progress and captured evidence to FILE
  --yes        Do not ask for install confirmation

Run one layer at a time. GPU installation requires a manual reboot before
--action verify. NPU installation requires the generated runtime and test
asset archives; verification runs the bundled VIPLite smoke test.
EOF
}
while (($#)); do
    case "$1" in
        --layer) LAYER=${2:?}; shift 2;;
        --action) ACTION=${2:?}; shift 2;;
        --log) LOG=${2:?}; shift 2;;
        --yes) YES=yes; shift;;
        -h|--help) usage; exit 0;;
        *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 2;;
    esac
done
[[ $LAYER =~ ^(gpu|vpu|npu)$ ]] || { echo 'ERROR: --layer must be gpu, vpu, or npu' >&2; exit 2; }
[[ $ACTION =~ ^(precheck|install|verify)$ ]] || { echo 'ERROR: --action must be precheck, install, or verify' >&2; exit 2; }
[[ $EUID -eq 0 ]] || { echo 'ERROR: run this workflow with sudo so its progress log is persistent.' >&2; exit 1; }
install -d -m 755 "$(dirname "$LOG")"

timestamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }
record() {
    printf '%s layer=%s action=%s status=%s detail=%s\n' \
        "$(timestamp)" "$LAYER" "$ACTION" "$1" "$2" >> "$LOG"
}
evidence="$LOG.$LAYER.$ACTION.txt"
record started "evidence=$evidence"

if [[ $ACTION == precheck || $ACTION == verify ]]; then
    set +e
    "$REPO_ROOT/tests/board/test-postboot-acceleration.sh" \
        "--$LAYER" --output "$evidence" 2>&1 | tee -a "$LOG"
    result=${PIPESTATUS[0]}
    set -e
    if ((result == 0)) && [[ $ACTION == verify && $LAYER == npu ]]; then
        set +e
        "$SCRIPT_DIR/test-npu.sh" 2>&1 | tee -a "$LOG"
        result=${PIPESTATUS[0]}
        set -e
        if ((result != 0)); then
            record failed "NPU smoke test failed"; exit "$result"
        fi
        record passed 'NPU VIPLite smoke test passed'
        exit 0
    fi
    if ((result == 0)); then
        record passed "board checks passed; evidence=$evidence"
        exit 0
    fi
    if [[ $ACTION == precheck ]]; then
        record baseline "pre-install checks reported expected warnings; evidence=$evidence"
        exit 0
    fi
    record failed "board checks failed; evidence=$evidence"
    exit "$result"
fi

if [[ $YES != yes ]]; then
    read -r -p "Install the $LAYER layer now and record the result? [y/N] " answer
    [[ $answer == y || $answer == Y ]] || { record skipped "user declined"; exit 0; }
fi

case "$LAYER" in
    gpu)
        printf 'Installing GPU only; VPU and x11vnc are disabled for this step.\n' | tee -a "$LOG"
        set +e
        "$REPO_ROOT/setup.sh" gpu --without-vpu --without-x11vnc 2>&1 | tee -a "$LOG"
        result=${PIPESTATUS[0]}
        set -e
        ;;
    vpu)
        archive="$REPO_ROOT/vendor-files/vpu-userspace.tar.gz"
        pvr_archive="$REPO_ROOT/vendor-files/pvr-userspace.tar.gz"
        [[ -f $archive && -f $pvr_archive ]] || {
            record failed "vendor-files requires pvr-userspace.tar.gz and vpu-userspace.tar.gz"; exit 1;
        }
        stage=$(mktemp -d -t zero3w-vpu-work.XXXXXXXX)
        trap 'rm -rf -- "$stage"' EXIT
        "$SCRIPT_DIR/prepare-vendor-archives.sh" --pvr-tarball "$pvr_archive" \
            --vpu-tarball "$archive" --output "$stage" >/dev/null
        printf 'Installing GStreamer command-line tools from the existing apt cache.\n' | tee -a "$LOG"
        apt-get install -y curl gstreamer1.0-tools gstreamer1.0-plugins-base \
            gstreamer1.0-plugins-good gstreamer1.0-plugins-bad 2>&1 | tee -a "$LOG"
        set +e
        "$SCRIPT_DIR/install-vpu-userspace.sh" --vendor-root "$stage/.zero3w-vpu" 2>&1 | tee -a "$LOG"
        result=${PIPESTATUS[0]}
        set -e
        ;;
    npu)
        archive="$REPO_ROOT/vendor-files/npu-userspace.tar.gz"
        test_archive="$REPO_ROOT/vendor-files/npu-test-assets.tar.gz"
        [[ -f $archive && -f $test_archive ]] || {
            record failed 'vendor-files requires npu-userspace.tar.gz and npu-test-assets.tar.gz'; exit 1;
        }
        stage=$(mktemp -d -t zero3w-npu-work.XXXXXXXX)
        trap 'rm -rf -- "$stage"' EXIT
        "$SCRIPT_DIR/prepare-vendor-archives.sh" --pvr-tarball "$REPO_ROOT/vendor-files/pvr-userspace.tar.gz" \
            --npu-tarball "$archive" --output "$stage" >/dev/null
        set +e
        "$SCRIPT_DIR/install-npu-userspace.sh" --vendor-root "$stage/.zero3w-npu" \
            --test-archive "$test_archive" 2>&1 | tee -a "$LOG"
        result=${PIPESTATUS[0]}
        set -e
        ;;
esac

if ((result == 0)); then
    if [[ $LAYER == vpu && $ACTION == verify ]]; then
        decode_evidence="$evidence.decode.txt"
        set +e
        "$SCRIPT_DIR/test-vpu-decode.sh" --output "$decode_evidence" 2>&1 | tee -a "$LOG"
        result=${PIPESTATUS[0]}
        set -e
        if ((result != 0)); then
            record failed "VPU decode test failed; evidence=$decode_evidence"
            exit "$result"
        fi
        record passed "VPU H.264/H.265 decode tests passed; evidence=$decode_evidence"
    fi
    record passed "installation completed"
    if [[ $LAYER == gpu ]]; then
        printf 'GPU install completed. Reboot manually, then run --action verify.\n' | tee -a "$LOG"
        record pending 'manual reboot required before verification'
    else
        printf '%s install completed. Run --action verify next.\n' "$LAYER" | tee -a "$LOG"
    fi
else
    record failed "installation exit=$result"
fi
exit "$result"
