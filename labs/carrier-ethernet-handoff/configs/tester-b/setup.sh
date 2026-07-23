#!/usr/bin/env bash
set -euo pipefail
sysctl -w net.ipv4.conf.all.arp_ignore=1 >/dev/null
ip link set eth1 mtu 1608 up
ip link add link eth1 name eth1.110 type vlan id 110
ip link add link eth1 name eth1.120 type vlan id 120
ip addr add 192.0.2.2/30 dev eth1.110
ip addr add 198.51.100.2/30 dev eth1.120
ip link set eth1.110 mtu 1600 up
ip link set eth1.120 mtu 1600 up
iperf3 -s -D
