#!/bin/bash
# server — enterprise Linux host on 10.100.0.0/30
#
# Sets up:
#   - IP address 10.100.0.2/30 on eth1 (link to core1)
#   - Default gateway via core1 (10.100.0.1)
#   - Removes ContainerLab management default route that would otherwise
#     compete with the data-plane default route
#
# After this runs, the server can reach the internet via:
#   server → core1 → edge → isp1 (primary)
#           (failover)    → isp2 (backup)

ip link set eth1 up
ip addr add 10.100.0.2/30 dev eth1 2>/dev/null || true

# Remove management default route so data-plane default takes over
ip route del default dev eth0 2>/dev/null || true

# Add default route via core1
ip route add default via 10.100.0.1 2>/dev/null || true
