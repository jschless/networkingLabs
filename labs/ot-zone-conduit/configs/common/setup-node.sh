#!/usr/bin/env bash
set -euo pipefail
install -d /run/ot
ip addr replace "$IP_ADDR" dev eth1
ip link set eth1 up
ip route replace default via "$GATEWAY"
if [[ -n "${POLLER_ROLE:-}" ]]; then
  nohup python3 /opt/ot/poller.py "$POLLER_ROLE" >/run/ot/poller.log 2>&1 &
fi
