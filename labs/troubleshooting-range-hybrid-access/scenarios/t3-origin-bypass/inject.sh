#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-hybrid-access
dir="$(cd "$(dirname "$0")" && pwd)"

"$dir/clear.sh"
docker exec "$prefix-cloud-edge" iptables -I FORWARD 1 \
    -s 10.70.10.0/24 -d 10.70.41.40 -p tcp --dport 8443 \
    -m comment --comment range-t3-origin-bypass -j ACCEPT
docker exec "$prefix-cloud-edge" ip6tables -I FORWARD 1 \
    -s 2001:db8:70:10::/64 -d 2001:db8:70:41::40 -p tcp --dport 8443 \
    -m comment --comment range-t3-origin-bypass -j ACCEPT

probe=(docker exec "$prefix-managed-client" python3 /opt/range/http_probe.py)
"${probe[@]}" 10.70.30.30 9443 protected-app-ok X-Client-Cert=managed-valid >/dev/null
"${probe[@]}" 10.70.30.30 9443 identity-denied X-Client-Cert=invalid >/dev/null
"${probe[@]}" 10.70.41.40 8443 protected-origin-ok >/dev/null
"${probe[@]}" 2001:db8:70:41::40 8443 protected-origin-ok >/dev/null
echo "Ticket symptom is active: approved identity checks still work while both direct origin paths are exposed."
