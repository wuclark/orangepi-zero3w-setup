#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
UPDATE=no
STATUS=no
while (($#)); do
    case "$1" in
        --update) UPDATE=yes; shift ;;
        --status) STATUS=yes; shift ;;
        -h|--help)
            cat <<'EOF'
Usage: sudo ./setup.sh core [--update|--status]

Install the username-independent SSH and board-maintenance core. The default
path uses the existing apt cache; --update explicitly refreshes apt metadata.
EOF
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

if [[ $STATUS == yes ]]; then
    systemctl is-enabled ssh 2>/dev/null || true
    systemctl is-active ssh 2>/dev/null || true
    dpkg-query -W -f='${Package} ${Version}\n' \
        openssh-server git curl rsync tmux htop jq ethtool pciutils usbutils lsof \
        2>/dev/null || true
    exit 0
fi

packages=(
    openssh-server ca-certificates curl git rsync tmux htop jq
    ethtool pciutils usbutils lsof less
)
if [[ $UPDATE == yes ]]; then
    apt-get update
else
    echo 'Using the existing apt cache; no apt update was run.'
fi
apt-get install -y --no-install-recommends "${packages[@]}"
systemctl enable --now ssh
install -d -m 755 /opt/orangepi-zero3w-setup/sources
install -d -m 755 /var/log/orangepi-zero3w-setup /var/backups/orangepi-zero3w-setup
printf 'Core maintenance layer installed. Setup path: /opt/orangepi-zero3w-setup\n'
