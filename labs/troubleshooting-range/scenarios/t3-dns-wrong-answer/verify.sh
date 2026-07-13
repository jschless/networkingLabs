#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-services1" grep -qx 'address=/web.range.test/10.250.40.10' /etc/dnsmasq.conf
answer="$(docker exec "$P-guest1" sh -lc 'timeout 3 nslookup web.range.test 10.250.40.10' 2>/dev/null || true)"
[[ "$answer" == *'10.250.40.10'* && "$answer" != *'198.18.0.10'* ]]
docker exec "$P-guest1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'
echo 'PASS: range DNS returns the approved address and the guest portal path works.'
