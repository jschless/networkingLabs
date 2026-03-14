#!/bin/bash
# host-c — LAN C client
# Pre-configured: IP address and default route via gw-c.
# Nothing to configure on this node.

ip addr add 192.168.3.10/24 dev eth1 2>/dev/null || true
ip link set eth1 up
ip route del default dev eth0 2>/dev/null || true
ip route add default via 192.168.3.1 2>/dev/null || true
