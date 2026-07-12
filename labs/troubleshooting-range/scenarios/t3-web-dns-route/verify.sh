#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
for _ in $(seq 1 15); do
    output="$(docker exec "$P-corp1" sh -lc 'timeout 3 nslookup web.range.test 10.250.40.10' || true)"
    if [[ "$output" == *'Name:'*'web.range.test'* ]] && \
       docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'; then
        echo "PASS: DNS resolution and web TCP reachability are restored."
        exit 0
    fi
    sleep 1
done
echo "FAIL: web service is not reachable through the normal DNS path" >&2
exit 1
