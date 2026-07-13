#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
docker exec "$P-edge2" vtysh -c 'configure terminal' -c 'router bgp 65000' -c 'no neighbor 192.0.2.3 remote-as 64502' -c 'neighbor 192.0.2.3 remote-as 64599' -c 'address-family ipv4 unicast' -c 'neighbor 192.0.2.3 activate' -c end
for _ in $(seq 1 15); do
  state="$(docker exec "$P-edge2" vtysh -c 'show bgp neighbor 192.0.2.3' || true)"
  if [[ "$state" != *'BGP state = Established'* ]]; then
    docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("198.18.10.10",8080),2).close()'
    echo 'Ticket symptom is active.'; exit 0
  fi
  sleep 1
done
exit 1
