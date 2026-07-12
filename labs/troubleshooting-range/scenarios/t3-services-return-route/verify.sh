#!/usr/bin/env bash
set -euo pipefail
for _ in $(seq 1 10); do
  output="$(docker exec clab-troubleshooting-range-corp1 sh -lc 'timeout 3 nslookup web.range.test 10.250.40.10' || true)"
  if [[ "$output" == *'Name:'*'web.range.test'* ]] && docker exec clab-troubleshooting-range-corp1 python3 -c 'import socket; socket.create_connection(("10.250.40.10",8080),2).close()'; then
    echo 'PASS: service return routing, DNS, and portal access are restored.'; exit 0
  fi
  sleep 1
done
exit 1
