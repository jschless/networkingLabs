#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-core1" ip link set eth3 mtu 1400
for _ in $(seq 1 30); do
    state="$(docker exec "$P-core1" vtysh -c 'show ip ospf neighbor' | grep '^10.250.255.22' || true)"
    if [[ "$state" == *ExStart* || "$state" == *Exchange* ]]; then
        docker exec "$P-corp1" ping -c 1 -W 1 10.250.40.10 >/dev/null
        echo 'Ticket symptom is active.'
        exit 0
    fi
    sleep 1
done
echo 'ERROR: OSPF adjacency did not enter the expected synchronization state' >&2
exit 1
