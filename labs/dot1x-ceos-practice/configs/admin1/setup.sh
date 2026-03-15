#!/bin/bash
set -e

ip link set eth1 up
ip addr add 192.168.199.30/24 dev eth1 2>/dev/null || true
ip route replace default via 192.168.199.1
