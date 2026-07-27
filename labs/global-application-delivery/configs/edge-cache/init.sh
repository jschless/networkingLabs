#!/bin/sh
set -eu
ip addr flush dev eth1
ip addr add 10.115.20.80/24 dev eth1
ip link set eth1 up
ip route replace 192.0.2.0/24 dev eth1
ip route replace 198.51.100.0/24 dev eth1
mkdir -p /run/nginx /var/cache/nginx/gad /var/log/gad
cp /opt/gad/nginx.conf /etc/nginx/nginx.conf.ready
: >/var/log/gad/cache.log
