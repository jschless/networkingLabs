#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-voice1" sh -lc "printf 'nameserver 10.250.20.254\\n' >/etc/resolv.conf"
docker exec "$P-voice1" ping -c 1 -W 1 10.250.40.10 >/dev/null
if docker exec "$P-voice1" timeout 3 getent ahostsv4 web.range.test >/dev/null 2>&1; then
    echo 'ERROR: ticket symptom did not become active' >&2
    exit 1
fi
echo 'Ticket symptom is active.'
