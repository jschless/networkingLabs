#!/bin/bash
# workstation — internal LAN user workstation
#
# IP:    10.0.0.6/30  (eth1, LAN-ws segment)
# GW:    10.0.0.5     (fw-inside)
#
# Simulates a corporate user workstation on the internal LAN.
# Permitted by policy:
#   - Outbound internet access (via fw-outside SNAT)
#   - Access to web-server (172.16.0.2) and mail-server (172.16.0.6) for management
# Blocked by policy:
#   - No inbound access from internet or DMZ

set -e

ip link set eth1 up
ip addr add 10.0.0.6/30 dev eth1

# Default route via fw-inside (all traffic — internet and DMZ — through fw-inside)
ip route del default 2>/dev/null || true
ip route add default via 10.0.0.5

echo "[workstation] Ready"
echo "  IP:       10.0.0.6/30"
echo "  Gateway:  10.0.0.5 (fw-inside)"
echo "  Internet: outbound allowed (NAT via fw-outside WAN 203.0.114.2)"
echo "  DMZ mgmt: web-server 172.16.0.2 and mail-server 172.16.0.6 reachable"
echo "  Inbound:  blocked by fw-inside (default drop)"
