#!/bin/bash
# h4 — host under acc2
# IP: 10.10.2.6/30, gateway: 10.10.2.5 (acc2 Ethernet4)

ip route del default dev eth0 2>/dev/null || true
ip addr add 10.10.2.6/30 dev eth1 2>/dev/null || true
ip link set eth1 up
ip route add default via 10.10.2.5 2>/dev/null || true
