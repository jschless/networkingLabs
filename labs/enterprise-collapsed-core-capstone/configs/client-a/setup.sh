#!/bin/bash
# client-a — VLAN 10 corporate client
# IP: 10.10.10.11/24
# Default gateway: 10.10.10.1 (VRRP VIP, cc1 active)

ip link set eth1 up
ip addr add 10.10.10.11/24 dev eth1 2>/dev/null || true
ip route del default 2>/dev/null || true
ip route add default via 10.10.10.1 2>/dev/null || true
