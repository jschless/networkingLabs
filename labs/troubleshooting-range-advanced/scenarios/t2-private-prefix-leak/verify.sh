#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced

! docker exec "$P-edge1" vtysh -c 'show running-config' | grep -q 'network 10.251.10.0/24'
for _ in $(seq 1 20); do
    isp="$(docker exec "$P-isp1" vtysh -c 'show bgp ipv4 unicast 10.251.10.0/24' 2>/dev/null || true)"
    external="$(docker exec "$P-internet-core" vtysh -c 'show bgp ipv4 unicast 10.251.10.0/24' 2>/dev/null || true)"
    [[ "$isp" == *'not in table'* && "$external" == *'not in table'* ]] && break
    sleep 1
done
[[ "$isp" == *'not in table'* && "$external" == *'not in table'* ]]
docker exec "$P-edge1" vtysh -c 'show bgp neighbor 192.0.2.1' | grep -q 'BGP state = Established'
docker exec "$P-core1" vtysh -c 'show ip route 10.251.10.0/24' | grep -q 'directly connected'
docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("198.18.10.10",8080),3).close()'
echo 'PASS: the private prefix is withdrawn externally and approved internal/internet service remains healthy.'
