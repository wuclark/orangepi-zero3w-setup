#!/usr/bin/env bash
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
result=$("$BUILD_DIR/vulkan-compute-benchmark" --shader-dir "$SHADER_DIR" "${BENCHMARK_ARGS[@]}" 2>&1 | tee /dev/stderr)
if [[ -n $OUTPUT ]]; then
    install -d -m 755 "$(dirname "$OUTPUT")"
    { echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "$result"; } > "$OUTPUT"
    echo "Evidence saved to $OUTPUT"
fi
