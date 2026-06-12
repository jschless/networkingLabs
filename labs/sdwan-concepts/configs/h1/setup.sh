#!/bin/sh
# h1 — host at site 1
#
#   eth1  10.1.0.10/24, gw 10.1.0.1 (branch1)

ip link set eth1 up
ip addr add 10.1.0.10/24 dev eth1 2>/dev/null || true
ip route del default 2>/dev/null || true
ip route add default via 10.1.0.1 2>/dev/null || true

echo "[h1] Ready — 10.1.0.10/24 via branch1"
