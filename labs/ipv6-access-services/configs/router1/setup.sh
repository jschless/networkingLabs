#!/bin/bash
set -e
ip link set eth1 up
sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null
ip -6 addr replace 2001:db8:10::1/64 dev eth1
mkdir -p /run/radvd
echo "[router1] IPv6 gateway ready on 2001:db8:10::1/64"
