#!/usr/bin/env bash
# Purpose: Enforce the repository's minimum documentation contract for maintained entrypoints.
# Platform: Host-side read-only test; it does not require a board or root.
# Inputs: Shell/configuration files, sidecars, and tests/documentation-contract-exceptions.txt.
# Writes: No persistent files; diagnostics go to stdout/stderr.
# Safety: Reads repository files only and never executes an entrypoint.
# Repeat: Idempotent and safe to run from any working directory.
# Recovery: No changes are made.
# Verification: Exit 0 means every scanned file has a contract header or justified exception.
set -Eeuo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
EXCEPTIONS="$REPO_ROOT/tests/documentation-contract-exceptions.txt"
declare -A exception_docs=()
declare -A exception_reasons=()
while IFS='|' read -r path reason documentation; do
    [[ -z ${path:-} || ${path:0:1} == '#' ]] && continue
    [[ -n ${reason:-} && -n ${documentation:-} ]] || { echo "Documentation contract: malformed exception: $path" >&2; exit 1; }
    [[ -f "$REPO_ROOT/$path" ]] || { echo "Documentation contract: exception path does not exist: $path" >&2; exit 1; }
    [[ -f "$REPO_ROOT/$documentation" ]] || { echo "Documentation contract: guide does not exist: $documentation" >&2; exit 1; }
    [[ -z ${exception_docs[$path]+x} ]] || { echo "Documentation contract: duplicate exception: $path" >&2; exit 1; }
    exception_reasons[$path]=$reason
    exception_docs[$path]=$documentation
done < "$EXCEPTIONS"

mapfile -t candidates < <(
    find "$REPO_ROOT/scripts" "$REPO_ROOT/tests" -type f -name '*.sh' -print
    printf '%s\n' "$REPO_ROOT/Makefile"
    find "$REPO_ROOT/config" "$REPO_ROOT/systemd" "$REPO_ROOT/manifests" "$REPO_ROOT/docker" -maxdepth 1 -type f \
        \( -name '*.conf' -o -name '*.service' -o -name '*.rules' -o -name '*.json' -o -name '*.env' -o -name '*.Dockerfile' \
        -o -name 'Xorg-*' -o -name '90-*' -o -name '95-*' \) -print
)

failures=0
for file in "${candidates[@]}"; do
    relative=${file#"$REPO_ROOT/"}
    if [[ -n ${exception_docs[$relative]+x} ]]; then
        printf 'EXEMPT %s (%s; see %s)\n' "$relative" "${exception_reasons[$relative]}" "${exception_docs[$relative]}"
        continue
    fi
    if [[ $relative == config/* || $relative == systemd/* || $relative == manifests/* || $relative == docker/* ]] &&
        ! grep -Eq '^[[:space:]]*(#|!|;|//|/\*|<!--)' "$file"; then
        sidecar="$REPO_ROOT/${relative}.md"
        if [[ ! -f $sidecar ]]; then
            echo "FAIL $relative: commentless configuration requires ${relative}.md or a documented exception" >&2
            failures=$((failures + 1))
            continue
        fi
        for field in '## Purpose' '## Consumer' '## Exact schema constraints' '## Safe changes' '## Verification' '## Why comments are impossible'; do
            if ! grep -Fq "$field" "$sidecar"; then
                echo "FAIL $relative: sidecar ${relative}.md is missing '$field'" >&2
                failures=$((failures + 1))
            fi
        done
        continue
    fi
    header=$(sed -n '1,45p' "$file")
    if [[ $relative == scripts/* || $relative == tests/* ]]; then
        for field in Purpose Inputs Writes Safety Verification; do
            if ! grep -Eq "^[[:space:]#]*${field}:" <<<"$header"; then
                echo "FAIL $relative: missing header field '$field' (or add a documented exception)" >&2
                failures=$((failures + 1))
            fi
        done
    elif ! grep -Eq '^[[:space:]#!]*(Purpose|Documentation):' <<<"$header"; then
        echo "FAIL $relative: missing Purpose/Documentation marker (or add a documented exception)" >&2
        failures=$((failures + 1))
    fi
done

if ((failures)); then
    echo "Documentation contract failed: $failures issue(s)." >&2
    exit 1
fi
echo "Documentation contract passed: ${#candidates[@]} files checked."
