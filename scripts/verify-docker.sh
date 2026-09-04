#!/usr/bin/env bash
# Purpose: Verify Docker client/daemon, Compose, Buildx, and a disposable hello-world container.
# Platform: Host workstation with Docker installed and daemon access.
# Inputs: Current Docker daemon, plugins, architecture, and network/cache availability.
# Dependencies: Bash, Docker, Compose plugin, Buildx plugin, and hello-world image access.
# Writes: Docker daemon state/cache may pull and run the disposable hello-world container; no repository files.
# Safety: Does not install Docker or alter board state; the container is run with --rm.
# Repeat: Safe to repeat; Docker may reuse or refresh the hello-world image.
# Recovery: Remove the local hello-world image/cache through normal Docker administration if desired.
# Outputs: PASS lines for client/server, architecture, Compose, Buildx, and hello-world.
# Verification: All checks and the container must succeed for exit 0.
# Documentation: docs/development/development.md
set -Eeuo pipefail

command -v docker >/dev/null 2>&1 || { echo 'FAIL: docker command not found.' >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo 'FAIL: Docker daemon is unavailable.' >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo 'FAIL: Docker Compose plugin is unavailable.' >&2; exit 1; }
docker buildx version >/dev/null 2>&1 || { echo 'FAIL: Docker Buildx plugin is unavailable.' >&2; exit 1; }

echo "PASS  Docker client/daemon: $(docker version --format '{{.Client.Version}} / {{.Server.Version}}')"
echo "PASS  Docker architecture:  $(docker info --format '{{.Architecture}}')"
echo "PASS  Docker Compose:       $(docker compose version)"
echo "PASS  Docker Buildx:        $(docker buildx version)"
echo 'Running hello-world container...'
docker run --rm hello-world >/dev/null
echo 'PASS  hello-world container'
