#!/usr/bin/env bash
set -euo pipefail
ip link set eth1 up
ip addr add 10.110.0.1/24 dev eth1
echo 'approved corporate service' >/srv/index.html
nohup python3 -m http.server 8080 --directory /srv --bind 10.110.0.1 >/var/log/service.log 2>&1 &
