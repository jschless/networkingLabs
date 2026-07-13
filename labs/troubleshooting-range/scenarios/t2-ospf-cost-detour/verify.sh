#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
! docker exec "$P-acc1" Cli -p 15 -c enable -c 'show running-config interfaces Ethernet1' | grep -q 'ip ospf cost'
for _ in $(seq 1 15); do
    route="$(docker exec "$P-acc1" Cli -p 15 -c enable -c 'show ip route 10.250.40.10')"
    if [[ "$route" == *'10.250.40.0/24 [110/20]'* && "$route" == *'via 10.250.0.0, Ethernet1'* ]]; then
        docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'
        echo 'PASS: the primary metric, next hop, and corporate service path are restored.'
        exit 0
    fi
    sleep 1
done
echo 'FAIL: the services route did not return to the golden primary path' >&2
exit 1
