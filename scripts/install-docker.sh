#!/usr/bin/env bash
# Purpose: Install Docker Engine, Compose, and the Docker repository for the board user.
# Platform: Supported Debian/Orange Pi architecture or another explicitly supported host architecture.
# Inputs: DOCKER_USER and DOCKER_APT_UPDATE; package/repository state from the current OS.
# Dependencies: Bash, root, dpkg, apt-get, curl, systemd, and network access to download.docker.com.
# Writes: Docker apt key/source files, installed packages, Docker service state, and user group membership.
# Safety: apt metadata refresh is opt-in; adding the user to docker grants root-equivalent Docker access.
# Repeat: Rewrites managed repository metadata and lets apt/systemd converge installed Docker state.
# Recovery: Remove Docker packages/repository using the documented host/board recovery procedure.
# Outputs: Installation logs and Docker verification commands.
# Verification: Run `docker version`, `docker compose version`, and `docker run hello-world`.
# Documentation: docs/development/development.md
set -Eeuo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_root

TARGET_USER=${DOCKER_USER:-$(resolve_real_user '')}
APT_UPDATE=${DOCKER_APT_UPDATE:-0}
ARCH=$(/usr/bin/dpkg --print-architecture)
[[ $ARCH == arm64 || $ARCH == amd64 || $ARCH == armhf || $ARCH == ppc64el || $ARCH == s390x ]] ||
    die "Docker's official repository does not support architecture: $ARCH"

/usr/bin/apt-get install -y ca-certificates curl
/usr/bin/install -m 0755 -d /etc/apt/keyrings
/usr/bin/curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
/usr/bin/chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
suite=${VERSION_CODENAME:-trixie}
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $suite
Components: stable
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/docker.asc
EOF

if [[ $APT_UPDATE == 1 || $APT_UPDATE == yes ]]; then
    /usr/bin/apt-get update
else
    log 'Docker repository configured without refreshing package metadata.'
    log 'If packages are unavailable, rerun with DOCKER_APT_UPDATE=1.'
fi

/usr/bin/apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
/usr/bin/systemctl enable --now docker.service
/usr/sbin/usermod -aG docker "$TARGET_USER"
log "Docker Engine, Buildx, and Compose installed for $TARGET_USER. Log in again for docker-group access."
log 'Verify with: docker version; docker compose version; docker run hello-world'
