#!/usr/bin/env bash
# Purpose: Install Docker Engine, Compose, and the Docker repository for the board user.
# Platform: Supported Debian/Orange Pi architecture or another explicitly supported host architecture.
# Inputs: DOCKER_USER and DOCKER_APT_UPDATE; package/repository state from the current OS.
# Dependencies: Bash, root, dpkg, apt-get, curl, systemd, and network access to download.docker.com.
# Writes: Docker apt key/source files, installed packages, Docker service state, user group membership, and removal of conflicting Debian Docker packages.
# Safety: apt metadata refresh is opt-in; removes only installed conflicting Debian Docker packages; adding the user to docker grants root-equivalent Docker access.
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
    # Fail fast when the new repository has no install candidate yet. This keeps
    # the no-refresh default (never run `apt update` implicitly) while replacing
    # apt's cryptic "no installation candidate" errors with the exact rerun.
    # apt-cache is read-only; it never refreshes metadata.
    candidate=$(/usr/bin/apt-cache policy docker-ce 2>/dev/null | /usr/bin/awk '/^[[:space:]]*Candidate:/ {print $2}')
    if [[ -z ${candidate:-} || $candidate == '(none)' ]]; then
        die "No docker-ce install candidate in the current apt cache. Rerun with DOCKER_APT_UPDATE=1 (example: sudo make board-docker-install DOCKER_APT_UPDATE=1 DOCKER_USER='$TARGET_USER')."
    fi
    log 'Using the existing apt cache; no apt update was run.'
fi

# Remove Debian-provided Docker packages that collide at the file level with
# Docker's official packages (proven on Armbian trixie: docker.io 26.1.5 and
# docker-compose 2.26.1-4; the latter owns the same cli-plugins/docker-compose
# path as docker-compose-plugin and aborts dpkg unpack). Only installed
# packages are removed in a single transaction; absent names are skipped so
# reruns stay idempotent.
conflicting_pkgs=(docker.io docker-doc docker-compose docker-compose-v2 docker-buildx podman-docker containerd runc)
to_remove=()
for conflicting in "${conflicting_pkgs[@]}"; do
    if /usr/bin/dpkg -s "$conflicting" >/dev/null 2>&1; then
        to_remove+=("$conflicting")
    fi
done
if ((${#to_remove[@]})); then
    log "Removing conflicting packages: ${to_remove[*]}"
    /usr/bin/apt-get remove -y "${to_remove[@]}"
fi

/usr/bin/apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
/usr/bin/systemctl enable --now docker.service
/usr/sbin/usermod -aG docker "$TARGET_USER"
log "Docker Engine, Buildx, and Compose installed for $TARGET_USER. Log in again for docker-group access."
log 'Verify with: docker version; docker compose version; docker run hello-world'
