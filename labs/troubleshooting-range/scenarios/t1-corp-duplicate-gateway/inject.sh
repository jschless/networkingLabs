#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
client="$P-corp1"

docker exec "$client" ip addr flush dev eth1 scope global
docker exec "$client" ip addr add 10.250.10.1/24 dev eth1
docker exec "$client" ip neigh flush dev eth1

docker exec "$client" ip -o -4 addr show dev eth1 | grep -q '10.250.10.1/24'
if docker exec "$client" arping -D -I eth1 -c 2 10.250.10.1 >/dev/null 2>&1; then
    echo 'ERROR: the injected address did not conflict with another host' >&2
    exit 1
fi
if docker exec "$client" ping -c 1 -W 1 10.250.50.10 >/dev/null 2>&1; then
    echo 'ERROR: off-subnet connectivity survived the address conflict' >&2
    exit 1
fi
echo 'Ticket symptom is active.'
