#!/bin/sh
set -eu
ip addr flush dev eth1
ip addr add 10.115.10.53/24 dev eth1
ip link set eth1 up
ip addr flush dev eth2
ip addr add 10.115.30.53/24 dev eth2
ip link set eth2 up
ip addr flush dev eth3
ip addr add 10.115.40.53/24 dev eth3
ip link set eth3 up
mkdir -p /run/gslb /var/log/gad
: >/run/gslb/hosts
: >/var/log/gad/health.log
coredns -conf /opt/gad/Corefile >/var/log/gad/coredns.log 2>&1 &
