#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-corp1" ip route show default | grep -q 'default via 10.250.10.1'
! docker exec "$P-corp1" ip neigh show 10.250.10.1 dev eth1 | grep -qi '02:00:00:00:10:fe\|PERMANENT'
docker exec "$P-corp1" ping -c 2 -W 2 10.250.40.10 >/dev/null
docker exec "$P-corp1" ping -c 2 -W 2 10.250.50.10 >/dev/null
echo 'PASS: the gateway neighbor is learned normally and corporate reachability is restored.'
