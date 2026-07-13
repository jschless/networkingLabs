#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-services1" sed -i 's|address=/web.range.test/10.250.40.10|address=/web.range.test/198.18.0.10|' /etc/dnsmasq.conf
docker exec "$P-services1" sh -lc 'pkill dnsmasq 2>/dev/null || true; sleep 1; dnsmasq --conf-file=/etc/dnsmasq.conf'
for _ in $(seq 1 10); do
    answer="$(docker exec "$P-guest1" sh -lc 'timeout 3 nslookup web.range.test 10.250.40.10' 2>/dev/null || true)"
    if [[ "$answer" == *'198.18.0.10'* ]]; then
        docker exec "$P-guest1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'
        if docker exec "$P-guest1" python3 -c 'import socket; socket.create_connection(("198.18.0.10", 8080), 1).close()' 2>/dev/null; then
            echo 'ERROR: wrong DNS target unexpectedly serves the portal' >&2
            exit 1
        fi
        echo 'Ticket symptom is active.'
        exit 0
    fi
    sleep 1
done
echo 'ERROR: DNS did not return the injected incorrect answer' >&2
exit 1
