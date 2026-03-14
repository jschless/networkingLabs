#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.20.20.11/24 dev eth1 2>/dev/null || true
ip route del default 2>/dev/null || true
ip route add default via 10.20.20.2 2>/dev/null || true

echo "[client-b] ready: static voice endpoint on VLAN 20"
