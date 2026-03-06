#!/bin/bash
# client-a — Corporate workstation, VLAN 10
#
# This host connects to acc1 eth2, which is configured as an access port
# in VLAN 10. The switch strips the VLAN tag, so the host uses the raw
# eth1 interface (no 802.1q subinterface needed).
#
# IP: 10.10.10.11/24, gateway: 10.10.10.1 (VRRP VIP on dist1/dist2)

set -e

ip link set eth1 up
ip addr add 10.10.10.11/24 dev eth1 2>/dev/null || true
ip route del default dev eth0 2>/dev/null || true
ip route add default via 10.10.10.1 2>/dev/null || true

echo "client-a ready: 10.10.10.11/24 gw 10.10.10.1"
