#!/usr/bin/env sh
set -eu
ip link set eth1 up
ip addr flush dev eth1 scope global || true
ip addr add 10.250.30.10/24 dev eth1
ip route replace default via 10.250.30.1
ip neigh flush dev eth1 || true
