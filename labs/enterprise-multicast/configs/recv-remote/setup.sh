#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.20.30.20/24 dev eth1
ip route replace default via 10.20.30.1

echo "[recv-remote] ready at 10.20.30.20/24"
