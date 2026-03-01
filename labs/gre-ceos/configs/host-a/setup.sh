#!/bin/bash
# host-a — LAN A end host
# Sets IP address, removes management default route, adds gateway route.

ip route del default dev eth0 2>/dev/null || true
ip addr add 192.168.1.10/24 dev eth1 2>/dev/null || true
ip link set eth1 up
ip route add default via 192.168.1.1 2>/dev/null || true
