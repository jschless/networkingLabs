#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.100.70.2/30 dev eth1
ip link set eth1 up
python3 /rtr_server.py >/var/log/rtr-server.log 2>&1 &
