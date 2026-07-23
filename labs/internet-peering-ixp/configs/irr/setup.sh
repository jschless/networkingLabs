#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.100.70.6/30 dev eth1
ip link set eth1 up
python3 -m http.server 8080 --directory /irr >/var/log/irr-http.log 2>&1 &
