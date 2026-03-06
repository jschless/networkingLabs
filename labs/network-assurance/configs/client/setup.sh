#!/bin/bash
set -e
ip link set eth1 up
ip addr add 10.1.0.2/30 dev eth1
ip route add default via 10.1.0.1
echo "[client] Ready: 10.1.0.2/30, gw 10.1.0.1"
