#!/bin/bash
# client — the "internet user" hitting the service
#
# IP:    203.0.113.2/29 (eth1, OUTSIDE segment)
# Route: 172.16.0.0/24 via 203.0.113.1 (edge)

ip link set eth1 up
ip addr add 203.0.113.2/29 dev eth1 2>/dev/null || true
ip route add 172.16.0.0/24 via 203.0.113.1 2>/dev/null || true

echo "[client] Ready — 203.0.113.2/29, DMZ via 203.0.113.1 (edge)"
