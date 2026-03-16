#!/bin/bash
set -e
ip link set eth1 up
ip addr replace 10.10.10.80/24 dev eth1
mkdir -p /srv/www
echo dhcp-dns-troubleshooting > /srv/www/index.html
python3 -m http.server 80 --directory /srv/www >/tmp/http.log 2>&1 &
echo "[app1] HTTP ready on 10.10.10.80"
