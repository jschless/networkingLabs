#!/bin/bash
set -e

ip link set eth1 up
ip addr replace 192.168.1.10/24 dev eth1
ip route replace default via 192.168.1.1

echo "[host-a] Ready: 192.168.1.10/24 via 192.168.1.1"
