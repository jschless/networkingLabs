#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-corp1" ip neigh replace 10.250.10.1 dev eth1 lladdr 02:00:00:00:10:fe nud permanent
docker exec "$P-corp1" ip route show default | grep -q 'default via 10.250.10.1'
if docker exec "$P-corp1" ping -c 1 -W 1 10.250.40.10 >/dev/null 2>&1; then
    echo 'ERROR: ticket symptom did not become active' >&2
    exit 1
fi
echo 'Ticket symptom is active.'
