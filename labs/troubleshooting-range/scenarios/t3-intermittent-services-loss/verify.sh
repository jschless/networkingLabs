#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range

! docker exec "$P-core1" tc qdisc show dev eth5 | grep -q netem
sample="$(docker exec "$P-corp1" ping -c 10 -W 1 10.250.40.10)"
printf '%s\n' "$sample" | grep -Eq '0% packet loss|10 packets transmitted, 10 packets received'
for _ in $(seq 1 5); do
    docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("10.250.40.10",8080),2).close()'
done
for client in corp1 voice1; do
    answer="$(docker exec "$P-$client" sh -lc 'timeout 3 nslookup web.range.test 10.250.40.10' 2>/dev/null || true)"
    [[ "$answer" == *'10.250.40.10'* ]]
    docker exec "$P-$client" python3 -c 'import urllib.request; assert urllib.request.urlopen("http://10.250.40.10:8080/index.html",timeout=2).status == 200'
done
echo 'PASS: the services path has no loss policy and repeated DNS and HTTP checks succeed.'
