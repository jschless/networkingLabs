#!/bin/sh
set -eu

ip link set eth1 up
ip address replace 10.1.0.2/24 dev eth1
ip route replace default via 10.1.0.1 dev eth1

echo "[client] 10.1.0.2/24 via 10.1.0.1"
