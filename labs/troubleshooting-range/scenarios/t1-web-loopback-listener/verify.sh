#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range

listeners="$(docker exec "$P-services1" ss -lnt '( sport = :8080 )')"
if [[ "$listeners" == *'127.0.0.1:8080'* ]]; then
    echo 'FAIL: the portal is still bound only to loopback' >&2
    exit 1
fi
[[ "$listeners" == *'10.250.40.10:8080'* ]]
docker exec "$P-services1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'
docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'
docker exec "$P-voice1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'
echo 'PASS: the portal listens on the service address and accepts remote clients.'
