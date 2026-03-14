#!/bin/bash
set -e

ip link set eth1 up
ip addr add 192.168.99.20/24 dev eth1

echo "[radius] simulated AAA endpoint ready at 192.168.99.20"
