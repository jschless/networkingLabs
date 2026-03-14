#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.20.20.20/24 dev eth1
ip route replace default via 10.20.20.1

echo "[recv-local] ready at 10.20.20.20/24"
