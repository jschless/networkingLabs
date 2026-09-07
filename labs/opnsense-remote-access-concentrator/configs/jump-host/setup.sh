#!/usr/bin/env bash
set -euo pipefail

ip addr replace 10.70.10.20/24 dev eth1
ip route replace default via 10.70.10.1
ip link set eth1 up
pkill -f '^python3 /tcp-responder.py 22 jump-host$' >/dev/null 2>&1 || true
nohup python3 /tcp-responder.py 22 jump-host \
  >/tmp/opnsense-ra-jump-host.log 2>&1 &
