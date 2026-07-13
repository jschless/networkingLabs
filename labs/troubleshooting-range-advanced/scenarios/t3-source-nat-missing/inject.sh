#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
docker exec "$P-edge1" iptables -t nat -D POSTROUTING -s 10.251.0.0/16 -o eth3 -j MASQUERADE
docker exec "$P-edge1" ping -I 192.0.2.0 -c 1 -W 2 198.18.10.10 >/dev/null
if docker exec "$P-corp1" python3 -c 'import socket; socket.create_connection(("198.18.10.10",8080),2).close()' 2>/dev/null; then exit 1; fi
echo 'Ticket symptom is active.'
