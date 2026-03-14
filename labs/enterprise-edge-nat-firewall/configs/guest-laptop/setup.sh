#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.0.0.10/30 dev eth1
ip route replace default via 10.0.0.9

echo "[guest-laptop] ready: 10.0.0.10/30 via 10.0.0.9"
