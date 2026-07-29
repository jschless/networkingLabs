#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-hybrid-access
dir="$(cd "$(dirname "$0")" && pwd)"

"$dir/clear.sh"
docker exec "$prefix-cloud-edge" iptables -I FORWARD 1 \
    -s 10.70.10.0/24 -d 10.70.41.40 -p tcp --dport 8080 \
    -m comment --comment range-t1-workload-port -j REJECT
docker exec "$prefix-cloud-edge" ip6tables -I FORWARD 1 \
    -s 2001:db8:70:10::/64 -d 2001:db8:70:41::40 -p tcp --dport 8080 \
    -m comment --comment range-t1-workload-port -j REJECT

probe=(docker exec "$prefix-managed-client" python3 /opt/range/http_probe.py)
if "${probe[@]}" 10.70.41.40 8080 cloud-app-a-ok >/dev/null 2>&1; then
    echo "ERROR: analytics symptom was not established" >&2
    exit 1
fi
"${probe[@]}" 10.70.41.40 8081 cloud-health-a-ok >/dev/null
"${probe[@]}" 10.70.42.40 8080 cloud-app-b-ok >/dev/null
docker exec "$prefix-managed-client" ping -c 1 -W 1 10.70.41.40 >/dev/null
echo "Ticket symptom is active: one application is denied while routing, health, and the secondary site remain healthy."
