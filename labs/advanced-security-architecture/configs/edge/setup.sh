#!/usr/bin/env bash
set -euo pipefail
ip addr add 192.0.2.1/24 dev eth1
ip addr add 198.51.100.1/30 dev eth2
ip link set eth1 up
ip link set eth2 up
sysctl -qw net.ipv4.ip_forward=1
ip route replace 10.114.0.0/16 via 198.51.100.2
ip route replace 198.51.100.80/32 via 198.51.100.2
ip route replace 203.0.113.0/24 via 192.0.2.10
nohup python3 /opt/lab/rtbh_api.py >/tmp/rtbh-api.log 2>&1 &
