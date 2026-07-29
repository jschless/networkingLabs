#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-hybrid-access
probe=(docker exec "$prefix-managed-client" python3 /opt/range/http_probe.py)

"${probe[@]}" 10.70.41.40 8080 cloud-app-a-ok >/dev/null
"${probe[@]}" 2001:db8:70:41::40 8080 cloud-app-a-ok >/dev/null
"${probe[@]}" 10.70.41.40 8081 cloud-health-a-ok >/dev/null
"${probe[@]}" 10.70.42.40 8080 cloud-app-b-ok >/dev/null
"${probe[@]}" --expect-denied 10.70.41.40 8443 >/dev/null
docker exec "$prefix-cloud-edge" sh -lc \
    "! iptables -S FORWARD | grep -q range-t1-workload-port"
docker exec "$prefix-cloud-edge" sh -lc \
    "! ip6tables -S FORWARD | grep -q range-t1-workload-port"
docker exec "$prefix-cloud-edge" sh -lc \
    "iptables -S FORWARD | grep -qx -- '-P FORWARD DROP'"
docker exec "$prefix-cloud-edge" sh -lc \
    "! iptables -S FORWARD | grep -Eq -- '-s 10\\.70\\.10\\.0/24 -d 10\\.70\\.41\\.40 -j ACCEPT$'"
echo "PASS: both address families reach the intended application, adjacent services remain healthy, direct protected-origin access stays denied, and no broad bypass exists."
