#!/bin/bash
# h1 — host under acc1
# IP: 10.10.1.2/30, gateway: 10.10.1.1 (acc1 Ethernet3)

ip route del default dev eth0 2>/dev/null || true
ip addr add 10.10.1.2/30 dev eth1 2>/dev/null || true
ip link set eth1 up
ip route add default via 10.10.1.1 2>/dev/null || true
