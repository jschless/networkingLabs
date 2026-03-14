#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.110.0.10/24 dev eth1
ip route replace default via 10.110.0.1

echo "[corp-sta] simulated enterprise wireless client ready"
