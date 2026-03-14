#!/bin/bash
# client-b — VLAN 20 voice client
# IP: 10.20.20.11/24
# Default gateway: 10.20.20.1 (VRRP VIP, cc2 active)

ip link set eth1 up
ip addr add 10.20.20.11/24 dev eth1 2>/dev/null || true
ip route del default 2>/dev/null || true
ip route add default via 10.20.20.1 2>/dev/null || true
