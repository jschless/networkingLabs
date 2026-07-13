#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
docker exec "$P-edge1" iptables -t nat -C POSTROUTING -s 10.251.0.0/16 -o eth3 -j MASQUERADE
docker exec "$P-core1" vtysh -c 'show ip route 198.18.10.0/24' | grep -q '10.251.0.1'
docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("198.18.10.10",8080),3).close()'
docker exec "$P-branch-client" python3 -c 'import socket; socket.create_connection(("198.18.10.10",8080),3).close()'
echo 'PASS: scoped source NAT and both client service paths are restored.'
