#!/bin/sh
set -eu
ip addr flush dev eth1
ip addr add 10.115.20.54/24 dev eth1
ip link set eth1 up
ip addr flush dev eth2
ip addr add 10.115.10.54/24 dev eth2
ip link set eth2 up
exec dnsmasq --no-daemon --conf-file=/opt/gad/dnsmasq.conf >/var/log/dnsmasq.log 2>&1 &
