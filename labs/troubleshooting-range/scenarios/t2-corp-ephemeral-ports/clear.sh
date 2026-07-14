#!/usr/bin/env bash
set -euo pipefail
client=clab-troubleshooting-range-corp1

docker exec "$client" pkill -f range_ephemeral_holder 2>/dev/null || true
docker exec "$client" sysctl -q -w 'net.ipv4.ip_local_port_range=32768 60999'
