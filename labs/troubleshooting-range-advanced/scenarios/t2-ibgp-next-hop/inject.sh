#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
docker exec "$P-edge1" vtysh -c 'configure terminal' -c 'router bgp 65000' -c 'address-family ipv4 unicast' -c 'no neighbor 10.251.0.5 next-hop-self' -c end -c 'clear bgp 10.251.0.5 soft out'
sleep 2
route="$(docker exec "$P-edge2" vtysh -c 'show bgp ipv4 unicast 198.18.10.0/24')"
[[ "$route" == *'192.0.2.3'* && "$route" != *'10.251.0.4 from 10.251.0.4'* ]]
docker exec "$P-branch-client" ping -c 1 -W 2 198.18.10.10 >/dev/null
echo 'Ticket symptom is active.'
