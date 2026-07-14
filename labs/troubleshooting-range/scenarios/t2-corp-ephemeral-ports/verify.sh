#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range

port_range="$(docker exec "$P-corp1" sysctl -n net.ipv4.ip_local_port_range)"
if [[ "$port_range" != $'32768\t60999' && "$port_range" != '32768 60999' ]]; then
    echo "FAIL: corporate ephemeral range is $port_range, expected 32768-60999" >&2
    exit 1
fi
existing="$(docker exec "$P-corp1" sh -lc "ss -Htan state established '( sport >= :40000 and sport <= :40003 and dport = :8080 )' | wc -l")"
[[ "$existing" -eq 4 ]]
docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'
[[ "$(docker exec "$P-corp1" sh -lc "ss -Htan state established '( sport >= :40000 and sport <= :40003 and dport = :8080 )' | wc -l")" -eq 4 ]]
docker exec "$P-voice1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'
echo 'PASS: the golden ephemeral range is restored, held sessions survived, and new sessions open.'
