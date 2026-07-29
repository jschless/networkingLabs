#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-hybrid-access
probe=(docker exec "$prefix-managed-client" python3 /opt/range/http_probe.py)

"${probe[@]}" 10.70.30.30 9443 protected-app-ok X-Client-Cert=managed-valid >/dev/null
"${probe[@]}" 10.70.30.30 9443 identity-denied X-Client-Cert=invalid >/dev/null
"${probe[@]}" --expect-denied 10.70.41.40 8443 >/dev/null
"${probe[@]}" --expect-denied 2001:db8:70:41::40 8443 >/dev/null
docker exec "$prefix-cloud-edge" sh -lc \
    "! iptables -S FORWARD | grep -q range-t3-origin-bypass"
docker exec "$prefix-cloud-edge" sh -lc \
    "! ip6tables -S FORWARD | grep -q range-t3-origin-bypass"
docker exec "$prefix-cloud-edge" sh -lc \
    "iptables -C FORWARD -s 10.70.30.30 -d 10.70.41.40 -p tcp --dport 8443 -j ACCEPT"
docker exec "$prefix-cloud-edge" sh -lc \
    "iptables -S FORWARD | grep -qx -- '-P FORWARD DROP'"
docker exec "$prefix-managed-client" sh -lc "! grep -q 'hybrid\\.test' /etc/hosts"
echo "PASS: managed identity reaches the protected application only through the PEP, unmanaged identity and direct origin paths are denied, and no host-file or broad-policy workaround remains."
