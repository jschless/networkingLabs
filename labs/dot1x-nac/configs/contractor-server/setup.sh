#!/bin/bash
# contractor-server/setup.sh — contractor resource (VLAN 20)
set -e

ip link set eth1 up
ip addr add 10.20.20.1/24 dev eth1 2>/dev/null || true

echo "[contractor-server] 10.20.20.1/24 ready — accessible only to VLAN 20 (PEAP authenticated)"
