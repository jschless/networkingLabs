#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
client="$P-corp1"

docker exec "$client" pkill -f range_ephemeral_holder 2>/dev/null || true
docker exec "$client" sysctl -q -w 'net.ipv4.ip_local_port_range=40000 40003'
docker exec -d "$client" python3 -c 'range_ephemeral_holder=True; import socket,time; sockets=[socket.create_connection(("10.250.40.10",8080),2) for _ in range(4)]; time.sleep(86400)'

for _ in $(seq 1 20); do
    count="$(docker exec "$client" sh -lc "ss -Htan state established '( dport = :8080 )' | wc -l")"
    [[ "$count" -eq 4 ]] && break
    sleep 0.1
done
[[ "$(docker exec "$client" sh -lc "ss -Htan state established '( dport = :8080 )' | wc -l")" -eq 4 ]]
docker exec "$P-voice1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'
if docker exec "$client" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 1).close()' 2>/dev/null; then
    echo 'ERROR: ticket symptom did not become active' >&2
    exit 1
fi
echo 'Ticket symptom is active.'
