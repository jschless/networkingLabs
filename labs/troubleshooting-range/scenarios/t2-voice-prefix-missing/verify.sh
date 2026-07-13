#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-acc1" Cli -p 15 -c enable -c 'show running-config section router ospf' | grep -q 'network 10.250.20.0/24 area 0.0.0.0'
docker exec "$P-core2" vtysh -c 'show ip route 10.250.20.10' | grep -q 'Known via "ospf"'
docker exec "$P-branch-client" ping -c 2 -W 2 10.250.20.10 >/dev/null
[[ "$(docker exec "$P-acc1" Cli -p 15 -c enable -c 'show ip ospf neighbor' | grep -ci full)" -ge 2 ]]
echo 'PASS: the voice prefix is advertised and remotely reachable with healthy peers.'
