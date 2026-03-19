#!/bin/bash
set -e

ip link set eth1 up
ip addr add 203.0.113.1/30 dev eth1

ip link set eth2 up
ip addr add 198.51.100.1/24 dev eth2

ip route replace 10.10.10.0/24 via 203.0.113.2
ip route replace 10.20.20.0/24 via 203.0.113.2
ip route replace 10.30.30.0/24 via 203.0.113.2
ip route replace 172.16.10.0/24 via 203.0.113.2

echo 1 > /proc/sys/net/ipv4/ip_forward

echo "[isp] Ready"
echo "  WAN toward FortiGate: 203.0.113.1/30"
echo "  Public segment:       198.51.100.1/24"
