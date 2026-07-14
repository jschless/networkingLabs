#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced

docker exec "$P-edge1" vtysh \
    -c 'configure terminal' \
    -c 'router bgp 65000' \
    -c 'address-family ipv4 unicast' \
    -c 'network 10.251.10.0/24' \
    -c end \
    -c 'clear bgp 192.0.2.1 soft out'

for _ in $(seq 1 20); do
    route="$(docker exec "$P-internet-core" vtysh -c 'show bgp ipv4 unicast 10.251.10.0/24' 2>/dev/null || true)"
    [[ "$route" == *'65000'* ]] && break
    sleep 1
done
docker exec "$P-edge1" vtysh -c 'show bgp ipv4 unicast neighbors 192.0.2.1 advertised-routes' | grep -q '10.251.10.0/24'
docker exec "$P-isp1" vtysh -c 'show bgp ipv4 unicast 10.251.10.0/24' | grep -q '65000'
docker exec "$P-internet-core" vtysh -c 'show bgp ipv4 unicast 10.251.10.0/24' | grep -q '65000'
docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("198.18.10.10",8080),3).close()'
echo 'Ticket symptom is active.'
