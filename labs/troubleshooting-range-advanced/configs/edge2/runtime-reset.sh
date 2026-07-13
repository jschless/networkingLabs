#!/usr/bin/env sh
set -eu
for i in eth1 eth2 eth3; do ip link set "$i" mtu 1500; done
iptables -t nat -F POSTROUTING
iptables -t nat -A POSTROUTING -s 10.251.0.0/16 -o eth3 -j MASQUERADE
iptables -F OUTPUT
