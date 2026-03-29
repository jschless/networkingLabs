#!/usr/bin/env bash
set -euo pipefail

ip link set eth1 up
ip link set eth2 up

ip addr add 172.20.20.20/32 dev lo
ip addr add 198.51.100.1/31 dev eth1
ip addr add 198.51.100.3/31 dev eth2

ip route add 192.168.10.0/24 \
  nexthop via 198.51.100.0 dev eth1 \
  nexthop via 198.51.100.2 dev eth2
