#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
service="$P-services1"
client="$P-corp1"

docker exec "$client" pkill -f range_accept_client 2>/dev/null || true
docker exec "$service" pkill -f range_accept_stall 2>/dev/null || true
docker exec "$service" pkill -f 'http.server 8080' 2>/dev/null || true
docker exec -d "$service" python3 -c 'range_accept_stall=True; import socket,time; s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); s.bind(("10.250.40.10",8080)); s.listen(1); time.sleep(86400)'

for _ in $(seq 1 20); do
    docker exec "$service" ss -H -lnt '( sport = :8080 )' | grep -q '10.250.40.10:8080' && break
    sleep 0.1
done
docker exec "$service" ss -H -lnt '( sport = :8080 )' | grep -q '10.250.40.10:8080'
docker exec -d "$client" python3 -c 'range_accept_client=True; import socket,time; sockets=[socket.create_connection(("10.250.40.10",8080),2) for _ in range(2)]; time.sleep(86400)'

for _ in $(seq 1 20); do
    queued="$(docker exec "$service" sh -lc "ss -H -lnt '( sport = :8080 )' | awk '{print \$2}'")"
    [[ "${queued:-0}" -ge 2 ]] && break
    sleep 0.1
done
queued="$(docker exec "$service" sh -lc "ss -H -lnt '( sport = :8080 )' | awk '{print \$2}'")"
[[ "${queued:-0}" -ge 2 ]]
docker exec "$P-voice1" ping -c 1 -W 1 10.250.40.10 >/dev/null
if docker exec "$P-voice1" timeout 2 python3 -c 'import socket; socket.create_connection(("10.250.40.10",8080),1).close()' 2>/dev/null; then
    echo 'ERROR: a new session unexpectedly entered the full accept queue' >&2
    exit 1
fi
echo 'Ticket symptom is active.'
