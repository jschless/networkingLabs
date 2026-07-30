#!/usr/bin/env bash
set -euo pipefail

prefix=clab-troubleshooting-range-hybrid-access
campus="$prefix-campus-edge"
cloud="$prefix-cloud-edge"
client="$prefix-managed-client"
dir="$(cd "$(dirname "$0")" && pwd)"
probe=(docker exec "$client" python3 /opt/range/http_probe.py)

"$dir/clear.sh"

docker exec "$cloud" ip route add blackhole 10.70.10.0/24 metric 5
docker exec "$cloud" ip -6 route add blackhole 2001:db8:70:10::/64 metric 5

docker exec "$campus" sh -c \
    "ip route get 10.70.41.40 | grep -q 'via 10.70.12.2'"
docker exec "$campus" sh -c \
    "ip -6 route get 2001:db8:70:41::40 |
         grep -q 'via 2001:db8:70:12::2'"
docker exec "$cloud" sh -c \
    "ip route show exact 10.70.10.0/24 |
         grep -Eq '^blackhole 10\\.70\\.10\\.0/24 metric 5[[:space:]]*$'"
docker exec "$cloud" sh -c \
    "ip -6 route show exact 2001:db8:70:10::/64 |
         grep -Eq '^blackhole 2001:db8:70:10::/64 dev lo metric 5 pref medium$'"

docker exec "$cloud" wget -qO- http://10.70.41.40:8080/ |
    grep -qx cloud-app-a-ok
docker exec "$cloud" wget -qO- 'http://[2001:db8:70:41::40]:8080/' |
    grep -qx cloud-app-a-ok

if "${probe[@]}" 10.70.41.40 8080 cloud-app-a-ok >/dev/null 2>&1; then
    echo "ERROR: IPv4 missing-reply symptom was not established" >&2
    exit 1
fi
if "${probe[@]}" 2001:db8:70:41::40 8080 cloud-app-a-ok \
    >/dev/null 2>&1; then
    echo "ERROR: IPv6 missing-reply symptom was not established" >&2
    exit 1
fi
if docker exec "$client" dig +time=1 +tries=1 \
    @10.70.53.53 analytics.hybrid.test A >/dev/null 2>&1; then
    echo "ERROR: IPv4 name-service symptom was not established" >&2
    exit 1
fi
if docker exec "$client" dig +time=1 +tries=1 \
    @2001:db8:70:53::53 analytics.hybrid.test AAAA >/dev/null 2>&1; then
    echo "ERROR: IPv6 name-service symptom was not established" >&2
    exit 1
fi

echo "Ticket symptom is active: both preferred hybrid routes remain selected and hosted services are healthy, but client requests receive no replies."
