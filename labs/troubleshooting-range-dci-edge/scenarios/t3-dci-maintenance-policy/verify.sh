#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-dci-edge

for _ in $(seq 1 20); do
    if docker exec "$prefix-b-prod" python3 /opt/range/http_probe.py \
        172.16.10.10 8080 site-a-prod-ok >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
docker exec "$prefix-b-prod" python3 /opt/range/http_probe.py \
    172.16.10.10 8080 site-a-prod-ok >/dev/null
docker exec "$prefix-a-prod" python3 /opt/range/http_probe.py \
    172.17.10.10 8080 site-b-prod-ok >/dev/null
docker exec "$prefix-b-prod" python3 /opt/range/http_probe.py \
    172.31.10.10 8080 shared-app-ok >/dev/null
docker exec "$prefix-a-bgw" Cli -p 15 -c "show bgp summary" |
    grep -E '10\.255\.10\.2.*Established' >/dev/null
docker exec "$prefix-b-leaf" Cli -p 15 -c \
    "show ip route vrf PROD 172.16.10.10/32" |
    grep -q 'via VTEP 10\.10\.0\.1 VNI 50010'
if docker exec "$prefix-a-bgw" Cli -p 15 -c "show running-config" |
    grep -q 'route-map DCI-PROD deny 5'; then
    echo "ERROR: stale maintenance policy remains" >&2
    exit 1
fi
if docker exec "$prefix-a-bgw" Cli -p 15 -c "show running-config" |
    grep -q 'ip route vrf PROD 172.17.10.0/24'; then
    echo "ERROR: static Site B tenant route masks the EVPN path" >&2
    exit 1
fi
if docker exec "$prefix-b-leaf" Cli -p 15 -c "show running-config" |
    grep -q 'ip route vrf PROD 172.16.10.0/24'; then
    echo "ERROR: static Site A tenant route masks the EVPN path" >&2
    exit 1
fi
echo "PASS: EVPN-derived inter-site service is restored in both directions, local/shared service remains healthy, and no static-route or L2-stretch workaround exists."
