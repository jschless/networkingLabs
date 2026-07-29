#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-dci-edge
dir="$(cd "$(dirname "$0")" && pwd)"

"$dir/clear.sh"
docker exec "$prefix-a-bgw" Cli -p 15 -c $'enable\nconfigure\nroute-map DCI-PROD deny 5\n match extcommunity DCI-PROD\nend\nclear bgp * soft out' >/dev/null

for _ in $(seq 1 15); do
    if ! docker exec "$prefix-b-prod" python3 /opt/range/http_probe.py \
        172.16.10.10 8080 site-a-prod-ok >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
if docker exec "$prefix-b-prod" python3 /opt/range/http_probe.py \
    172.16.10.10 8080 site-a-prod-ok >/dev/null 2>&1; then
    echo "ERROR: inter-site symptom was not established" >&2
    exit 1
fi
docker exec "$prefix-a-prod" python3 /opt/range/http_probe.py \
    172.31.10.10 8080 shared-app-ok >/dev/null
docker exec "$prefix-a-prod" python3 /opt/range/http_probe.py \
    172.16.10.10 8080 site-a-prod-ok >/dev/null
docker exec "$prefix-b-prod" python3 /opt/range/http_probe.py \
    172.17.10.10 8080 site-b-prod-ok >/dev/null
docker exec "$prefix-a-bgw" Cli -p 15 -c "show bgp summary" |
    grep -E '10\.255\.10\.2.*Established' >/dev/null
echo "Ticket symptom is active: site-local services remain healthy while Site A inter-site production routes are suppressed."
