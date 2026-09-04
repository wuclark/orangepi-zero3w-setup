#!/usr/bin/env bash
# Purpose: Build the host Docker image used by the vendor archive extraction workflow.
# Platform: Host workstation with Docker; it does not run on the Orange Pi board.
# Inputs: Optional DOCKER_IMAGE and DOCKERFILE environment variables.
# Dependencies: Bash, Docker, repository Dockerfile, and the host build context.
# Writes: Docker image layers and local Docker cache; no board or system paths are modified.
# Safety: Uses --pull=false and reuses an existing tagged image; never runs a board installer.
# Repeat: Idempotently reuses the image when the requested tag already exists.
# Recovery: Remove the local Docker image/cache using normal Docker administration if needed.
# Outputs: Build progress or a reuse message and Docker exit status.
# Verification: Run `scripts/verify-docker.sh` or the archive tests after building.
# Documentation: docs/development/development.md
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
