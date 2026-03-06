#!/bin/bash
# employee-server/setup.sh — protected employee resource (VLAN 10)
set -e

ip link set eth1 up
ip addr add 10.10.10.1/24 dev eth1 2>/dev/null || true

echo "[employee-server] 10.10.10.1/24 ready — accessible only to VLAN 10 (EAP-TLS authenticated)"
