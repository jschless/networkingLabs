#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
service="$P-services1"

docker exec "$service" pkill -f 'http.server 8080' 2>/dev/null || true
docker exec -d "$service" python3 -m http.server 8080 --bind 127.0.0.1 --directory /srv/range-web

for _ in $(seq 1 100); do
    docker exec "$service" python3 -c 'import socket; socket.create_connection(("127.0.0.1", 8080), 1).close()' 2>/dev/null && break
    sleep 0.1
done
docker exec "$service" python3 -c 'import socket; socket.create_connection(("127.0.0.1", 8080), 1).close()'
docker exec "$P-corp1" ping -c 1 -W 1 10.250.40.10 >/dev/null
if docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 1).close()' 2>/dev/null; then
    echo 'ERROR: ticket symptom did not become active' >&2
    exit 1
fi
echo 'Ticket symptom is active.'
