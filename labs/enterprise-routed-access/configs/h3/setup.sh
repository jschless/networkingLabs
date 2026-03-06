#!/bin/bash
# h3 — host under acc2
# IP: 10.10.2.2/30, gateway: 10.10.2.1 (acc2 Ethernet3)

ip route del default dev eth0 2>/dev/null || true
ip addr add 10.10.2.2/30 dev eth1 2>/dev/null || true
ip link set eth1 up
ip route add default via 10.10.2.1 2>/dev/null || true
