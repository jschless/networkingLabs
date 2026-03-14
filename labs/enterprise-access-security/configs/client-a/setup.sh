#!/bin/bash
set -e

ip link set eth1 up
ip addr flush dev eth1
ip route del default 2>/dev/null || true

dhclient -v -1 eth1 || true

echo "[client-a] ready for DHCP-based access security tests"
