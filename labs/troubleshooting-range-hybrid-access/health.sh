#!/usr/bin/env bash
set -euo pipefail

prefix=clab-troubleshooting-range-hybrid-access
passed=0
failed=0

ok() { printf '  PASS %s\n' "$1"; passed=$((passed + 1)); }
bad() { printf '  FAIL %s — %s\n' "$1" "$2"; failed=$((failed + 1)); }
node() { docker exec "$prefix-$1" sh -lc "$2"; }
probe() { docker exec "$prefix-managed-client" python3 /opt/range/http_probe.py "$@"; }

check() {
    local label=$1
    shift
    if "$@" >/dev/null 2>&1; then ok "$label"; else bad "$label" "assertion failed"; fi
}

for name in managed-client campus-edge wan-a wan-b cloud-edge pep origin-a origin-b dns; do
    docker inspect "$prefix-$name" >/dev/null 2>&1 || {
        echo "ERROR: hybrid access range is not fully deployed (missing $name)" >&2
        exit 2
    }
done

echo "=== Hybrid Access Troubleshooting Range health gate ==="
check "WAN A IPv4 transport is up" node campus-edge "ping -c 1 -W 1 10.70.12.2"
check "WAN B IPv4 transport is up" node campus-edge "ping -c 1 -W 1 10.70.13.2"
check "WAN A IPv6 transport is up" node cloud-edge "ping -6 -c 1 -W 1 2001:db8:70:24::1"
check "WAN B IPv6 transport is up" node cloud-edge "ping -6 -c 1 -W 1 2001:db8:70:25::1"
check "IPv4 primary path selects WAN A" node campus-edge "ip route get 10.70.41.40 | grep -q 'via 10.70.12.2'"
check "IPv6 primary path selects WAN A" node campus-edge "ip -6 route get 2001:db8:70:41::40 | grep -q 'via 2001:db8:70:12::2'"
check "managed client reaches DNS over IPv4" node managed-client "ping -c 1 -W 1 10.70.53.53"
check "managed client reaches DNS over IPv6" node managed-client "ping -6 -c 1 -W 1 2001:db8:70:53::53"
check "DNS A answer is authoritative" node managed-client "dig +short @10.70.53.53 analytics.hybrid.test A | grep -qx 10.70.41.40"
check "DNS AAAA answer is authoritative" node managed-client "dig +short @2001:db8:70:53::53 analytics.hybrid.test AAAA | grep -qx 2001:db8:70:41::40"
check "site A application is healthy over IPv4" probe 10.70.41.40 8080 cloud-app-a-ok
check "site A application is healthy over IPv6" probe 2001:db8:70:41::40 8080 cloud-app-a-ok
check "site B application is healthy" probe 10.70.42.40 8080 cloud-app-b-ok
check "site B health endpoint is healthy" probe 10.70.42.40 8081 cloud-health-b-ok
check "managed identity reaches the protected application" probe 10.70.30.30 9443 protected-app-ok X-Client-Cert=managed-valid
check "unmanaged identity is denied by the PEP" probe 10.70.30.30 9443 identity-denied X-Client-Cert=invalid
check "direct protected-origin access is denied over IPv4" probe --expect-denied 10.70.41.40 8443
check "direct protected-origin access is denied over IPv6" probe --expect-denied 2001:db8:70:41::40 8443

rules="$(node cloud-edge "iptables -S FORWARD; ip6tables -S FORWARD")"
if [[ "$rules" != *range-t1-workload-port* && "$rules" != *range-t3-origin-bypass* ]]; then
    ok "no scenario marker remains in cloud policy"
else
    bad "scenario policy cleanup" "a fault marker remains"
fi
check "cloud IPv4 forwarding default is deny" node cloud-edge "iptables -S FORWARD | grep -qx -- '-P FORWARD DROP'"
check "cloud IPv6 forwarding default is deny" node cloud-edge "ip6tables -S FORWARD | grep -qx -- '-P FORWARD DROP'"
check "no netem qdisc remains on WAN links" node campus-edge "! tc qdisc show | grep -q netem"

host_epoch="$(date +%s)"
container_epoch="$(node managed-client "date +%s")"
clock_delta=$((host_epoch - container_epoch))
(( clock_delta < 0 )) && clock_delta=$((-clock_delta))
if (( clock_delta <= 5 )); then ok "assessment clock differs from host by at most 5 seconds"
else bad "assessment clock" "delta is ${clock_delta}s"; fi

printf 'Results: %d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
