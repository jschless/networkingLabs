#!/usr/bin/env sh
set -eu
ip link set eth1 mtu 1400
ip link set eth2 mtu 1500
ip link set eth3 mtu 1500
iptables -t nat -F POSTROUTING
iptables -t nat -A POSTROUTING -s 10.251.0.0/16 -o eth3 -j MASQUERADE
iptables -F OUTPUT
