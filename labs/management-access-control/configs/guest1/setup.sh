#!/bin/bash
set -e
ip link set eth1 up
ip addr replace 192.168.50.10/24 dev eth1
ip route replace default via 192.168.50.1
echo "[guest1] Ready: 192.168.50.10/24"
