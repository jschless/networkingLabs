#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
docker exec "$P-edge1" vtysh -c 'configure terminal' -c 'ip prefix-list BLOCK-IN seq 5 deny 198.18.10.0/24' -c 'ip prefix-list BLOCK-IN seq 100 permit 0.0.0.0/0 le 32' -c 'route-map BLOCK-IN permit 10' -c 'match ip address prefix-list BLOCK-IN' -c 'router bgp 65000' -c 'address-family ipv4 unicast' -c 'neighbor 192.0.2.1 route-map BLOCK-IN in' -c end -c 'clear bgp 192.0.2.1 soft in'
sleep 2
summary="$(docker exec "$P-edge1" vtysh -c 'show bgp neighbor 192.0.2.1')"
route="$(docker exec "$P-edge1" vtysh -c 'show bgp ipv4 unicast 198.18.10.0/24')"
[[ "$summary" == *'BGP state = Established'* && "$route" == *'10.251.0.5'* && "$route" != *'localpref 200'* ]]
docker exec "$P-corp1" ping -c 1 -W 2 198.18.10.10 >/dev/null
echo 'Ticket symptom is active.'
