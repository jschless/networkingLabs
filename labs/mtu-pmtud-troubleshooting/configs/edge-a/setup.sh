#!/bin/bash
set -e

echo 1 > /proc/sys/net/ipv4/ip_forward
ip link set eth1 up
ip link set eth2 up
ip link set eth2 mtu 1400

ip addr replace 192.168.1.1/24 dev eth1
ip addr replace 203.0.113.1/30 dev eth2
ip route replace 203.0.113.4/30 via 203.0.113.2 dev eth2

ip tunnel add gre1 mode gre local 203.0.113.1 remote 203.0.113.6 ttl 255
ip addr replace 172.16.0.1/30 dev gre1
ip link set gre1 up
ip route replace 192.168.2.0/24 via 172.16.0.2 dev gre1

echo "[edge-a] GRE up, WAN MTU 1400, tunnel MTU left at default for troubleshooting"
