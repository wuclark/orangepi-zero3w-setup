#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

usage() {
    cat <<'EOF'
Orange Pi Zero 3W setup

Usage:
  sudo ./setup.sh base [options]
  sudo ./setup.sh packages [options]
  sudo ./setup.sh desktop --profile PROFILE [options]
  sudo ./setup.sh remote --backend BACKEND [options]
  sudo ./setup.sh gpu [existing GPU installer options]
  sudo ./setup.sh vpu [--status|--install|--verify]
  sudo ./setup.sh npu [--status]
  sudo ./setup.sh status
  sudo ./setup.sh reset
  sudo ./setup.sh uninstall

The base command is CLI-only and does not run apt update, upgrade packages,
install a GUI, or reboot. Package changes are always explicit.
EOF
}

command_name=${1:-help}
shift || true
case "$command_name" in
    base) exec "$REPO_ROOT/scripts/setup-base.sh" "$@" ;;
    packages) exec "$REPO_ROOT/scripts/armbian-provision.sh" "$@" ;;
    desktop) exec "$REPO_ROOT/scripts/setup-desktop.sh" "$@" ;;
    remote) exec "$REPO_ROOT/scripts/setup-remote.sh" "$@" ;;
    gpu) exec "$REPO_ROOT/install.sh" "$@" ;;
    vpu) exec "$REPO_ROOT/scripts/setup-vpu.sh" "$@" ;;
    npu) exec "$REPO_ROOT/scripts/setup-npu.sh" "$@" ;;
    status) exec "$REPO_ROOT/scripts/setup-status.sh" "$@" ;;
    reset) exec "$REPO_ROOT/scripts/setup-reset.sh" "$@" ;;
    uninstall) exec "$REPO_ROOT/scripts/setup-uninstall.sh" "$@" ;;
    help|-h|--help) usage ;;
    *) echo "Unknown command: $command_name" >&2; usage >&2; exit 2 ;;
esac
