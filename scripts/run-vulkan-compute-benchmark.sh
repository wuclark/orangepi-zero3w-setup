#!/usr/bin/env bash
# Purpose: Compile and run the repository Vulkan vector/matrix compute benchmark.
# Platform: Host Lavapipe baseline or Orange Pi PowerVR board, depending on the selected Vulkan ICD.
# Inputs: Optional output/build directories and benchmark options such as elements or iterations.
# Dependencies: Bash, glslc or glslangValidator, g++, Vulkan loader/development files, and benchmark sources.
# Writes: Shader/binary build artifacts under BUILD_DIR and optional timestamped evidence at OUTPUT.
# Safety: Runs a bounded compute workload; does not install packages, change drivers, or reboot.
# Repeat: Rebuilds the local benchmark artifacts and replaces only the explicitly requested evidence output.
# Recovery: Remove the configured temporary build/output paths if generated artifacts are unwanted.
# Outputs: Benchmark results, timings, optional evidence file, and child exit status.
# Verification: Compare computed results with the benchmark's CPU references and inspect the saved log.
# Documentation: docs/optional/gpu/gpu.md
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_DIR=${BUILD_DIR:-/tmp/zero3w-vulkan-compute}
OUTPUT=
BENCHMARK_ARGS=()
while (($#)); do
    case "$1" in
        --output) OUTPUT=${2:?}; shift 2;;
        --build-dir) BUILD_DIR=${2:?}; shift 2;;
        --elements|--matrix-size|--iterations)
            BENCHMARK_ARGS+=("$1" "${2:?}"); shift 2;;
        -h|--help) echo "Usage: $0 [--output FILE] [--build-dir DIR] [-- BENCHMARK_OPTIONS]"; exit 0;;
        --) shift; BENCHMARK_ARGS+=("$@"); break;;
        *) echo "ERROR: unknown option: $1" >&2; exit 2;;
    esac
done
SHADER_DIR="$BUILD_DIR/shaders"
mkdir -p "$SHADER_DIR"
compiler=$(command -v glslc || command -v glslangValidator || true)
[[ -n $compiler ]] || { echo "ERROR: glslc or glslangValidator is required." >&2; exit 1; }
if [[ ${compiler##*/} == glslc ]]; then
    glslc -O "$REPO_ROOT/benchmarks/vulkan/vector_add.comp" -o "$SHADER_DIR/vector_add.comp.spv"
    glslc -O "$REPO_ROOT/benchmarks/vulkan/matrix_mul.comp" -o "$SHADER_DIR/matrix_mul.comp.spv"
else
    glslangValidator -V -o "$SHADER_DIR/vector_add.comp.spv" "$REPO_ROOT/benchmarks/vulkan/vector_add.comp"
    glslangValidator -V -o "$SHADER_DIR/matrix_mul.comp.spv" "$REPO_ROOT/benchmarks/vulkan/matrix_mul.comp"
fi
g++ -O2 -std=c++17 "$REPO_ROOT/benchmarks/vulkan/vulkan-compute-benchmark.cpp" -lvulkan -o "$BUILD_DIR/vulkan-compute-benchmark"
run_log=$(mktemp -t zero3w-vulkan-compute.XXXXXXXX)
trap 'rm -f -- "$run_log"' EXIT
set +e
"$BUILD_DIR/vulkan-compute-benchmark" --shader-dir "$SHADER_DIR" "${BENCHMARK_ARGS[@]}" >"$run_log" 2>&1
run_status=$?
set -e
cat "$run_log"
result=$(<"$run_log")
if [[ -n $OUTPUT ]]; then
    install -d -m 755 "$(dirname "$OUTPUT")"
    { echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "$result"; } > "$OUTPUT"
    echo "Evidence saved to $OUTPUT"
fi
exit "$run_status"
