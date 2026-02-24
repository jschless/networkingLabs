#!/bin/bash
# host-a — LAN A client
# Pre-configured: IP address and default route
# Nothing for you to configure on this node.

ip addr add 192.168.1.10/24 dev eth1 2>/dev/null || true
ip link set eth1 up
ip route add default via 192.168.1.1 2>/dev/null || true
