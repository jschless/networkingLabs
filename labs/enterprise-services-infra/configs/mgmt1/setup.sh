#!/bin/bash
set -e

ip link set eth1 up
ip addr add 192.168.99.30/24 dev eth1
ip route replace default via 192.168.99.1

echo "[mgmt1] ready on VLAN 99 for admin validation"
