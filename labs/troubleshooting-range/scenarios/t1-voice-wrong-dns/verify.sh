#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-voice1" grep -qx 'nameserver 10.250.40.10' /etc/resolv.conf
address="$(docker exec "$P-voice1" getent ahostsv4 web.range.test | awk 'NR == 1 {print $1}')"
[[ "$address" == 10.250.40.10 ]]
docker exec "$P-voice1" python3 -c 'import socket; socket.create_connection(("10.250.40.10", 8080), 2).close()'
echo 'PASS: voice DNS configuration and name-based portal access are restored.'
