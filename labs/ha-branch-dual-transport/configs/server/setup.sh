#!/usr/bin/env bash
# server — DC application server behind the hub.
set -euo pipefail
ip link set eth1 up
ip addr add 10.20.20.100/24 dev eth1
ip route del default 2>/dev/null || true
ip route add default via 10.20.20.1
