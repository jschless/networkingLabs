#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-services1" iptables -I INPUT 1 -p tcp -s 10.250.20.0/24 --dport 8080 -j DROP
answer="$(docker exec "$P-voice1" sh -lc 'timeout 3 nslookup web.range.test 10.250.40.10' 2>/dev/null || true)"
[[ "$answer" == *'10.250.40.10'* ]]
docker exec "$P-voice1" ping -c 1 -W 1 10.250.40.10 >/dev/null
docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'
if docker exec "$P-voice1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()' 2>/dev/null; then
    echo 'ERROR: ticket symptom did not become active' >&2
    exit 1
fi
echo 'Ticket symptom is active.'
