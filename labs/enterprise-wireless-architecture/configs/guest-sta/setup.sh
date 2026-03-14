#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.120.0.10/24 dev eth1
ip route replace default via 10.120.0.1

echo "[guest-sta] simulated guest wireless client ready"
