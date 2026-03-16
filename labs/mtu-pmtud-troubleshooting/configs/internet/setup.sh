#!/bin/bash
set -e

echo 1 > /proc/sys/net/ipv4/ip_forward
ip link set eth1 up
ip link set eth2 up
ip link set eth1 mtu 1400
ip link set eth2 mtu 1400

ip addr replace 203.0.113.2/30 dev eth1
ip addr replace 203.0.113.5/30 dev eth2

echo "[internet] Transit path ready with WAN MTU 1400"
