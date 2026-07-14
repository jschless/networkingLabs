#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced

for _ in $(seq 1 30); do
    peer="$(docker exec "$P-edge1" vtysh -c 'show bgp neighbor 192.0.2.1' 2>/dev/null || true)"
    service_route="$(docker exec "$P-edge1" vtysh -c 'show bgp ipv4 unicast 198.18.10.0/24' 2>/dev/null || true)"
    added_route="$(docker exec "$P-edge1" vtysh -c 'show bgp ipv4 unicast 203.0.113.0/24' 2>/dev/null || true)"
    if [[ "$peer" == *'BGP state = Established'* && "$service_route" == *'192.0.2.1'* && "$added_route" == *'192.0.2.1'* ]]; then
        break
    fi
    sleep 1
done
maximum="$(printf '%s\n' "$peer" | awk '/Maximum prefixes allowed/ {print $4}')"
[[ "${maximum:-0}" -ge 2 ]]
[[ "$service_route" == *'localpref 200'* && "$added_route" == *'localpref 200'* ]]
docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("198.18.10.10",8080),3).close()'
echo 'PASS: maximum-prefix protection remains, both approved routes are accepted, ISP1 is preferred, and service works.'
