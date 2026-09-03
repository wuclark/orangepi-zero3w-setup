#!/usr/bin/env bash
# Purpose: Install the board's system benchmark tools and headless graph renderer.
# Platform: Debian/Armbian board with a configured APT cache; requires root.
# Inputs: existing APT metadata; this script deliberately does not run apt update.
# Writes: installed packages including sysbench, fio, iperf3, and gnuplot-nox.
# Safety: package installation only; no benchmark or storage write runs here.
# Repeat behavior: apt installation is idempotent and keeps already-installed tools.
# Recovery: rerun after fixing APT/package errors; use board-system-benchmark to verify.
# Verification: command -v each tool and generate a stability PNG on the board.
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo.' >&2; exit 1; }
# Deliberately do not run apt update; use the existing apt cache.
apt-get install -y sysbench p7zip-full openssl mbw fio iperf3 gnuplot-nox
echo 'System benchmark dependencies installed.'
