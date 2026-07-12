#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
{
    printf '%s\n' enable configure 'interface Ethernet3' shutdown end
} | docker exec -i "$P-acc1" Cli -p 15 >/dev/null
for _ in $(seq 1 10); do
    if ! docker exec "$P-corp1" ping -c 1 -W 1 10.250.50.10 >/dev/null 2>&1; then
        echo "Ticket symptom is active."
        exit 0
    fi
    sleep 1
done
echo "ERROR: ticket symptom did not become active" >&2
exit 1
