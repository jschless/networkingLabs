#!/bin/sh
set -eu

ip address flush dev eth1
ip address add 10.0.0.20/24 dev eth1
ip link set eth1 up
install -d -m 0700 /etc/wireguard

echo "gw-b WAN scaffold ready"
