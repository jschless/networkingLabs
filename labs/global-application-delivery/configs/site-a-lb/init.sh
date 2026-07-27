#!/bin/sh
set -eu
ip addr flush dev eth1
ip addr add 10.115.20.101/24 dev eth1
ip addr add 192.0.2.10/32 dev eth1
ip link set eth1 up
ip addr flush dev eth2
ip addr add 10.115.30.10/24 dev eth2
ip link set eth2 up
mkdir -p /run/haproxy /var/log/gad
cp /opt/gad/haproxy.cfg /etc/haproxy/haproxy.cfg.ready
: >/var/log/gad/haproxy.log
