#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.70.10.20/24 dev eth1
ip route replace default via 10.70.10.1
ip link set eth1 up
while true; do printf 'jump host\n' | nc -l -p 22 -q 1 2>/dev/null || true; done &
