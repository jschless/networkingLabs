#!/usr/bin/env bash
set -euo pipefail
ip link add USER type vrf table 1010
ip link add SERVER type vrf table 1020
ip link set USER up
ip link set SERVER up
ip link add link eth1 name eth1.110 type vlan id 110
ip link add link eth1 name eth1.120 type vlan id 120
ip link set eth1 up
ip link set eth1.110 master USER
ip link set eth1.120 master SERVER
ip link set eth2 master USER
ip link set eth3 master SERVER
ip addr add 10.114.254.2/30 dev eth1.110
ip addr add 10.114.254.6/30 dev eth1.120
ip addr add 10.114.10.1/24 dev eth2
ip addr add 10.114.20.1/24 dev eth3
ip link set eth1.110 up
ip link set eth1.120 up
ip link set eth2 up
ip link set eth3 up
sysctl -qw net.ipv4.ip_forward=1
ip route replace vrf USER default via 10.114.254.1
ip route replace vrf SERVER default via 10.114.254.5
