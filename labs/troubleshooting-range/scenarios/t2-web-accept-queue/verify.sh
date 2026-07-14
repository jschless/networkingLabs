#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range

! docker exec "$P-services1" pgrep -f range_accept_stall >/dev/null
! docker exec "$P-corp1" pgrep -f range_accept_client >/dev/null
docker exec "$P-services1" pgrep -f 'python3 -m http.server 8080' >/dev/null
queue="$(docker exec "$P-services1" sh -lc "ss -H -lnt '( sport = :8080 )' | awk '{print \$2}'")"
[[ "${queue:-1}" -eq 0 ]]
for client in corp1 voice1; do
    docker exec "$P-$client" python3 -c 'import socket; socket.create_connection(("10.250.40.10",8080),2).close()'
    docker exec "$P-$client" python3 -c 'import urllib.request; data=urllib.request.urlopen("http://10.250.40.10:8080/index.html",timeout=2).read(); assert data == b"troubleshooting-range-web\n"'
done
echo 'PASS: the approved web process is accepting sessions and both client networks complete HTTP requests.'
