#!/usr/bin/env bash
set -euo pipefail
ip addr add "$IP" dev eth1
ip link set eth1 up
ip route replace default via "$GW"
if [[ "${SERVICE:-}" == "private" ]]; then
  python3 -m http.server 8443 --bind 0.0.0.0 --directory / >/tmp/private-app.log 2>&1 &
elif [[ "${SERVICE:-}" == "saas" ]]; then
  python3 -m http.server 8080 --bind 0.0.0.0 --directory / >/tmp/saas.log 2>&1 &
fi
