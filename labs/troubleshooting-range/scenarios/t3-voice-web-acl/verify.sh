#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
if docker exec "$P-services1" iptables -C INPUT -p tcp -s 10.250.20.0/24 --dport 8080 -j DROP 2>/dev/null; then
    echo 'FAIL: the source-specific drop rule is still installed' >&2
    exit 1
fi
answer="$(docker exec "$P-voice1" sh -lc 'timeout 3 nslookup web.range.test 10.250.40.10' 2>/dev/null || true)"
[[ "$answer" == *'10.250.40.10'* ]]
docker exec "$P-voice1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'
docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'
echo 'PASS: voice and corporate clients reach the portal and the bad policy is absent.'
