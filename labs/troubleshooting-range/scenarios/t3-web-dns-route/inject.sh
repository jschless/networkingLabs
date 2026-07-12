#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-core1" vtysh -c 'configure terminal' -c 'interface eth5' -c shutdown -c end
for _ in $(seq 1 15); do
    output="$(docker exec "$P-corp1" sh -lc 'timeout 2 nslookup web.range.test 10.250.40.10' 2>/dev/null || true)"
    if [[ "$output" != *'Name:'*'web.range.test'* ]]; then
        echo "Ticket symptom is active."
        exit 0
    fi
    sleep 1
done
echo "ERROR: ticket symptom did not become active" >&2
exit 1
