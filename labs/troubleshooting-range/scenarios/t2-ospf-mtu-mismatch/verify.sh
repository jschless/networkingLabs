#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
[[ "$(docker exec "$P-core1" cat /sys/class/net/eth3/mtu)" == 1500 ]]
[[ "$(docker exec "$P-core2" cat /sys/class/net/eth3/mtu)" == 1500 ]]
! docker exec "$P-core1" vtysh -c 'show running-config interface eth3' | grep -q 'mtu-ignore'
for _ in $(seq 1 30); do
    left="$(docker exec "$P-core1" vtysh -c 'show ip ospf neighbor' | grep '^10.250.255.22' || true)"
    right="$(docker exec "$P-core2" vtysh -c 'show ip ospf neighbor' | grep '^10.250.255.21' || true)"
    if [[ "$left" == *Full* && "$right" == *Full* ]]; then
        docker exec "$P-corp1" ping -c 2 -W 2 10.250.40.10 >/dev/null
        echo 'PASS: transit MTUs match, the adjacency is Full, and service reachability works.'
        exit 0
    fi
    sleep 1
done
echo 'FAIL: the core adjacency did not return to Full' >&2
exit 1
