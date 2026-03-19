#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.10.10.10/24 dev eth1
ip route replace default via 10.10.10.1

echo "[corp-client] Ready"
echo "  IP:       10.10.10.10/24"
echo "  Gateway:  10.10.10.1"
