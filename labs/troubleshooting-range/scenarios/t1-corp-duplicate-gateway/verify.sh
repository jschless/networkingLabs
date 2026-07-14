#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
client="$P-corp1"

addresses="$(docker exec "$client" ip -o -4 addr show dev eth1 scope global)"
[[ "$addresses" == *'10.250.10.10/24'* ]]
[[ "$addresses" != *'10.250.10.1/24'* ]]
docker exec "$client" ip route show default | grep -q '^default via 10.250.10.1 dev eth1'
docker exec "$client" arping -D -I eth1 -c 2 10.250.10.10 >/dev/null
docker exec "$client" ping -c 2 -W 2 10.250.10.1 >/dev/null
docker exec "$client" ping -c 2 -W 2 10.250.50.10 >/dev/null
echo 'PASS: the approved client address, unique ownership, default route, and remote reachability are restored.'
