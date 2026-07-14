#!/usr/bin/env sh
set -eu
ip link set eth1 up
ip addr flush dev eth1 scope global || true
ip addr add 10.250.40.10/24 dev eth1
ip route replace default via 10.250.40.1
ip neigh flush dev eth1 || true
pkill dnsmasq 2>/dev/null || true
pkill -f 'http.server 8080' 2>/dev/null || true
pkill -f range_accept_stall 2>/dev/null || true
sleep 1
cp /etc/dnsmasq.conf.orig /etc/dnsmasq.conf
dnsmasq --conf-file=/etc/dnsmasq.conf >/tmp/dnsmasq.log 2>&1 &
mkdir -p /srv/range-web
printf 'troubleshooting-range-web\n' >/srv/range-web/index.html
python3 -m http.server 8080 --bind 10.250.40.10 --directory /srv/range-web >/tmp/web.log 2>&1 &
