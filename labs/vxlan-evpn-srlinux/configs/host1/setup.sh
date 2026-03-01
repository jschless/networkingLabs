#!/bin/bash
# host1 — connected to vtep1's VNI 100 bridge port (ethernet-1/2)
# IP on the L2 segment

ip route del default dev eth0 2>/dev/null || true
ip addr add 172.16.0.1/24 dev eth1 2>/dev/null || true
ip link set eth1 up
