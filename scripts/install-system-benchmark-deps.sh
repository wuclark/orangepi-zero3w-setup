#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo.' >&2; exit 1; }
# Deliberately do not run apt update; use the existing apt cache.
apt-get install -y sysbench p7zip-full openssl mbw fio iperf3
echo 'System benchmark dependencies installed.'
