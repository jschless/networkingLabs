#!/usr/bin/env bash
set -euo pipefail
service=clab-troubleshooting-range-services1

docker exec "$service" pkill -f 'http.server 8080' 2>/dev/null || true
docker exec -d "$service" python3 -m http.server 8080 --bind 10.250.40.10 --directory /srv/range-web
for _ in $(seq 1 100); do
    if docker exec "$service" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 1).close()' 2>/dev/null; then
        exit 0
    fi
    sleep 0.1
done
echo 'ERROR: portal listener did not return on the service address' >&2
exit 1
