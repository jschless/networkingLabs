#!/usr/bin/env bash
set -euo pipefail
ip addr add 192.0.2.10/24 dev eth1
ip link set eth1 up
ip addr add 203.0.113.53/32 dev lo
ip addr add 203.0.113.80/32 dev lo
ip addr add 203.0.113.200/32 dev lo
ip route replace default via 192.0.2.1
LAB_ROLE=internet-test LAB_PORT=8080 nohup python3 /opt/lab/http_service.py >/tmp/http.log 2>&1 &
nohup dnsmasq --no-daemon --no-resolv --bind-interfaces \
    --listen-address=203.0.113.53 \
    --address=/approved.test/203.0.113.80 \
    --address=/blocked.test/203.0.113.80 >/tmp/dns.log 2>&1 &
