#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.114.20.20/24 dev eth1
ip link set eth1 up
ip route replace default via 10.114.20.1
LAB_ROLE=protected-app LAB_PORT=8080 LAB_SYSLOG=10.114.60.10:514 \
    nohup python3 /opt/lab/http_service.py >/tmp/app.log 2>&1 &
