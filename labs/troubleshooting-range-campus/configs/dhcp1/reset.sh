#!/usr/bin/env sh
set -eu
ip link set eth1 up
ip addr flush dev eth1 scope global || true
ip addr add 10.252.10.2/24 dev eth1
ip route replace default via 10.252.10.1
ip neigh flush dev eth1 || true
pkill dnsmasq 2>/dev/null || true
sleep 1
cp /etc/dnsmasq.conf.orig /etc/dnsmasq.conf
dnsmasq --conf-file=/etc/dnsmasq.conf >/tmp/dnsmasq.log 2>&1 &
