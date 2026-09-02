#!/usr/bin/env bash
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
