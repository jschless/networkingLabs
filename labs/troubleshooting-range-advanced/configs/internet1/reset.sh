#!/usr/bin/env sh
set -eu
ip link set eth1 up
ip link set eth1 mtu 1500
ip addr flush dev eth1 scope global || true
ip addr add 198.18.10.10/24 dev eth1
ip route replace default via 198.18.10.1
ip neigh flush dev eth1 || true
pkill -f 'http.server 8080' 2>/dev/null || true
sleep 1
mkdir -p /srv/internet
printf 'advanced-range-small\n' >/srv/internet/index.html
dd if=/dev/zero of=/srv/internet/large.bin bs=1024 count=64 2>/dev/null
python3 -m http.server 8080 --bind 198.18.10.10 --directory /srv/internet >/tmp/http.log 2>&1 &
