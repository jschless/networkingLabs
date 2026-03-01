#!/bin/bash
# host2 — connected to vtep2's VNI 100 bridge port (ethernet-1/2)
# IP on the L2 segment

ip route del default dev eth0 2>/dev/null || true
ip addr add 172.16.0.2/24 dev eth1 2>/dev/null || true
ip link set eth1 up
