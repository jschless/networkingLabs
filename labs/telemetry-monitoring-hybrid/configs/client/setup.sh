#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.10.10.11/24 dev eth1
ip route replace default via 10.10.10.1

echo "[client] Ready: 10.10.10.11/24 -> 10.10.10.1"
