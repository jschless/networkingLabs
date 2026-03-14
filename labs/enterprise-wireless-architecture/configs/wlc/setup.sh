#!/bin/bash
set -e

ip link set eth1 up
ip addr add 192.168.99.10/24 dev eth1
python3 -m http.server 8080 --bind 192.168.99.10 >/tmp/wlc.log 2>&1 &

echo "[wlc] lightweight controller endpoint ready on http://192.168.99.10:8080"
