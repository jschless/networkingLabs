#!/bin/sh
# h2 — host at site 2
#
#   eth1  10.2.0.10/24, gw 10.2.0.1 (branch2)

ip link set eth1 up
ip addr add 10.2.0.10/24 dev eth1 2>/dev/null || true
ip route del default 2>/dev/null || true
ip route add default via 10.2.0.1 2>/dev/null || true

echo "[h2] Ready — 10.2.0.10/24 via branch2"
