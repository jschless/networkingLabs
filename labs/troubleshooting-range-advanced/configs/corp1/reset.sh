#!/usr/bin/env sh
set -eu
ip link set eth1 up
ip link set eth1 mtu 1500
ip addr flush dev eth1 scope global || true
ip addr add 10.251.10.10/24 dev eth1
ip route replace default via 10.251.10.1
ip neigh flush dev eth1 || true
