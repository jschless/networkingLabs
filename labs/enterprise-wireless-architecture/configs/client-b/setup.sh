#!/bin/bash
# client-b — Voice endpoint, VLAN 20
#
# This host connects to acc3 eth2, which is configured as an access port
# in VLAN 20. The switch strips the VLAN tag, so the host uses the raw
# eth1 interface (no 802.1q subinterface needed).
#
# IP: 10.20.20.11/24, gateway: 10.20.20.1 (VRRP VIP on dist1/dist2)

set -e

ip link set eth1 up
ip addr add 10.20.20.11/24 dev eth1 2>/dev/null || true
ip route del default dev eth0 2>/dev/null || true
ip route add default via 10.20.20.1 2>/dev/null || true

echo "client-b ready: 10.20.20.11/24 gw 10.20.20.1"
