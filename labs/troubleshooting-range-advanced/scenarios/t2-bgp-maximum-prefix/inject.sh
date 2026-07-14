#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced

docker exec "$P-edge1" vtysh \
    -c 'configure terminal' \
    -c 'router bgp 65000' \
    -c 'address-family ipv4 unicast' \
    -c 'neighbor 192.0.2.1 maximum-prefix 1' \
    -c end
docker exec "$P-internet-core" vtysh \
    -c 'configure terminal' \
    -c 'ip route 203.0.113.0/24 Null0' \
    -c 'router bgp 64500' \
    -c 'address-family ipv4 unicast' \
    -c 'network 203.0.113.0/24' \
    -c end \
    -c 'clear bgp 192.0.2.4 soft out'

for _ in $(seq 1 30); do
    peer="$(docker exec "$P-edge1" vtysh -c 'show bgp neighbor 192.0.2.1' 2>/dev/null || true)"
    [[ "$peer" == *'Maximum Number of Prefixes Reached'* && "$peer" != *'BGP state = Established'* ]] && break
    sleep 1
done
[[ "$peer" == *'Maximum Number of Prefixes Reached'* && "$peer" == *'Maximum prefixes allowed 1'* ]]
for _ in $(seq 1 20); do
    if docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("198.18.10.10",8080),3).close()' 2>/dev/null; then
        echo 'Ticket symptom is active.'
        exit 0
    fi
    sleep 1
done
echo 'ERROR: backup service path did not converge' >&2
exit 1
