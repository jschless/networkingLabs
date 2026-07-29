#!/usr/bin/env bash
set -euo pipefail

prefix=clab-troubleshooting-range-dci-edge
passed=0
failed=0
nodes=(
    a-leaf a-bgw b-bgw b-leaf peer
    a-prod b-prod shared-app edge-client
    internet-client inspection public-origin
    carrier-test-a carrier-nid-a carrier-core carrier-nid-b carrier-test-b
    storage-init storage-path-a storage-path-b storage-target
)

ok() { printf '  PASS %s\n' "$1"; passed=$((passed + 1)); }
bad() { printf '  FAIL %s — %s\n' "$1" "$2"; failed=$((failed + 1)); }
node() { docker exec "$prefix-$1" "${@:2}"; }
shell_node() { docker exec "$prefix-$1" sh -lc "$2"; }
eos() { docker exec "$prefix-$1" Cli -p 15 -c "$2"; }
probe() { node "$1" python3 /opt/range/http_probe.py "${@:2}"; }
eos_grep() { eos "$1" "$2" | grep -Eq "$3"; }
eos_not_grep() { ! eos "$1" "$2" | grep -Eq "$3"; }

check() {
    local label=$1
    shift
    if "$@" >/dev/null 2>&1; then ok "$label"; else bad "$label" "assertion failed"; fi
}

for name in "${nodes[@]}"; do
    docker inspect "$prefix-$name" >/dev/null 2>&1 || {
        echo "ERROR: DCI edge range is not fully deployed (missing $name)" >&2
        exit 2
    }
done

echo "=== DCI Edge Troubleshooting Range health gate ==="
check "Site A local EVPN session is established" eos_grep a-leaf \
    "show bgp summary" '10\.11\.0\.2.*Established'
check "Site B local EVPN session is established" eos_grep b-leaf \
    "show bgp summary" '10\.21\.0\.1.*Established'
check "inter-site EVPN session is established" eos_grep a-bgw \
    "show bgp summary" '10\.255\.10\.2.*Established'
check "external peer session is established" eos_grep a-bgw \
    "show bgp summary" '203\.0\.113\.2.*Established'
check "Site A installs remote PROD through EVPN" eos_grep a-leaf \
    "show ip route vrf PROD 172.17.10.10/32" 'via VTEP 10\.20\.0\.1 VNI 50010'
check "Site B installs remote PROD through EVPN" eos_grep b-leaf \
    "show ip route vrf PROD 172.16.10.10/32" 'via VTEP 10\.10\.0\.1 VNI 50010'
check "Site A PROD reaches Site B application" probe a-prod \
    172.17.10.10 8080 site-b-prod-ok
check "Site B PROD reaches Site A application" probe b-prod \
    172.16.10.10 8080 site-a-prod-ok
check "Site B PROD reaches the shared application" probe b-prod \
    172.31.10.10 8080 shared-app-ok
check "DEV routes remain site-local" eos_not_grep a-leaf \
    "show ip route vrf DEV" '172\.17\.20\.0/24'
check "approved partner application prefix is reachable" node edge-client \
    ping -c 1 -W 1 198.51.100.10
check "peer health prefix is reachable" node edge-client \
    ping -c 1 -W 1 198.51.100.20

check "carrier Gold service is healthy" node carrier-test-a \
    ping -I eth1.110 -c 1 -W 1 192.0.2.2
check "carrier Silver service is healthy" node carrier-test-a \
    ping -I eth1.120 -c 1 -W 1 198.51.100.2
check "carrier committed 1600-byte MTU passes" node carrier-test-a \
    ping -I eth1.110 -M "do" -c 1 -W 2 -s 1572 192.0.2.2
carrier_flows="$(node carrier-nid-b ovs-ofctl -O OpenFlow13 dump-flows br-service)"
if [[ "$carrier_flows" == *"dl_vlan=120"* && "$carrier_flows" == *"set_field:7216->vlan_vid"* &&
      "$carrier_flows" == *"dl_vlan=110"* && "$carrier_flows" == *"set_field:7196->vlan_vid"* &&
      "$carrier_flows" != *"actions=NORMAL"* && "$carrier_flows" != *"actions=FLOOD"* ]]; then
    ok "carrier services retain distinct explicit mappings"
else
    bad "carrier service isolation" "expected explicit 110-to-3100 and 120-to-3120 mappings"
fi

check "storage path A carries exact 9000-byte IP packets" node storage-init \
    ping -I eth1 -c 1 -W 2 -s 8972 10.92.10.20
check "storage path B carries exact 9000-byte IP packets" node storage-init \
    ping -I eth2 -c 1 -W 2 -s 8972 10.92.20.20
check "storage service is reachable over path A" probe storage-init \
    10.92.10.20 3260 storage-session-ready
check "storage service is reachable over path B" probe storage-init \
    10.92.20.20 3260 storage-session-ready
check "no storage impairment qdisc remains" shell_node storage-path-a \
    "! tc qdisc show | grep -q netem"

check "inspected public application path is healthy" probe internet-client \
    10.90.20.20 8080 inspected-origin-ok
check "direct protected-origin path is denied" probe internet-client \
    --expect-denied 203.0.113.20 8443
check "inspection forwarding remains default deny" shell_node inspection \
    "iptables -S FORWARD | grep -qx -- '-P FORWARD DROP'"
check "no DCI maintenance scenario marker remains" eos_not_grep a-bgw \
    "show running-config" 'route-map DCI-PROD deny 5'

host_epoch="$(date +%s)"
container_epoch="$(node edge-client date +%s)"
clock_delta=$((host_epoch - container_epoch))
(( clock_delta < 0 )) && clock_delta=$((-clock_delta))
if (( clock_delta <= 5 )); then
    ok "assessment clock differs from host by at most 5 seconds"
else
    bad "assessment clock" "delta is ${clock_delta}s"
fi

printf 'Results: %d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
