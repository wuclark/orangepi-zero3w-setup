#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
DOCKER_IMAGE=${DOCKER_IMAGE:-orangepi-zero3w-setup/extraction-toolchain:bookworm-20260824}
DOCKERFILE=${DOCKERFILE:-$REPO_ROOT/docker/extraction-toolchain.Dockerfile}
command -v docker >/dev/null 2>&1 || { echo 'ERROR: docker is required' >&2; exit 1; }
[[ -f $DOCKERFILE ]] || { echo "ERROR: Dockerfile not found: $DOCKERFILE" >&2; exit 1; }
if docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
    echo "Reusing Docker toolchain image: $DOCKER_IMAGE"
    exit 0
fi
docker build --pull=false -f "$DOCKERFILE" -t "$DOCKER_IMAGE" "$REPO_ROOT"
