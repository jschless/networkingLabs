#!/bin/sh
set -eu
ip addr flush dev eth1
ip addr add 10.115.20.102/24 dev eth1
ip addr add 198.51.100.10/32 dev eth1
ip link set eth1 up
ip addr flush dev eth2
ip addr add 10.115.40.10/24 dev eth2
ip link set eth2 up
mkdir -p /run/haproxy /var/log/gad
cp /opt/gad/haproxy.cfg /etc/haproxy/haproxy.cfg.ready
: >/var/log/gad/haproxy.log
