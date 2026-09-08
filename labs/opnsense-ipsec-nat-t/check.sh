#!/usr/bin/env bash
# Read-only exact grader for native OPNsense 26.1 IKEv2/NAT-T state.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck source=scripts/check-lib.sh
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "opnsense-ipsec-nat-t"

lab_dir="$REPO_ROOT/labs/opnsense-ipsec-nat-t"
# shellcheck source=labs/opnsense-ipsec-nat-t/lab-lib.sh
source "$lab_dir/lab-lib.sh"

assert_flag() {
    local label=$1 output=$2 key=$3
    if grep -qxF "$key=1" <<<"$output"; then
        pass "$label"
    else
        fail "$label" "expected state is absent or inconsistent"
    fi
}

assert_exact() {
    local label=$1 actual=$2 expected=$3
    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label" "expected state is absent or inconsistent"
    fi
}

assert_local_ping() {
    local label=$1 node=$2 destination=$3
    if docker exec "$NATT_PREFIX-$node" ping -c 3 -W 2 "$destination" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label" "traffic probe did not succeed"
    fi
}

assert_remote_ping() {
    local label=$1 port=$2 destination=$3
    if natt_ssh "$port" "ping -c 2 -W 2000 $destination" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label" "traffic probe did not succeed"
    fi
}

if natt_require_tools >/dev/null 2>&1; then
    pass "required host tooling is available"
else
    fail "required host tooling is available" "one or more runtime dependencies are missing"
fi

node_inventory=$(docker ps --format '{{.Names}}' | grep -c "^${NATT_PREFIX}-" || true)
assert_exact "incidental node inventory is exact" "$node_inventory" "3"
for node in nat-cpe hq-host branch-host; do
    image=$(docker inspect --format '{{.Config.Image}}' "$NATT_PREFIX-$node" 2>/dev/null || true)
    assert_exact "$node uses the pinned incidental-role image" "$image" "ops-lab:local"
done

if natt_ssh_ready "$NATT_HQ_PORT"; then
    pass "HQ firewall management is ready"
else
    fail "HQ firewall management is ready" "loopback-only management probe failed"
fi
if natt_ssh_ready "$NATT_BRANCH_PORT"; then
    pass "Branch firewall management is ready"
else
    fail "Branch firewall management is ready" "loopback-only management probe failed"
fi

hq_saved=$(natt_php "$NATT_HQ_PORT" hq "" "$lab_dir/grade-config.php" 2>/dev/null || true)
branch_saved=$(natt_php "$NATT_BRANCH_PORT" branch "" "$lab_dir/grade-config.php" 2>/dev/null || true)
for check in \
    'interfaces|saved data-interface state' \
    'enc0_registered|saved encrypted-interface registration' \
    'gateway|saved underlay gateway state' \
    'legacy_rules|saved data-interface policy state' \
    'connection|saved IKE connection inventory' \
    'local_auth|saved local-auth inventory' \
    'remote_auth|saved remote-auth inventory' \
    'child|saved CHILD policy inventory' \
    'psk|saved PSK identity and digest' \
    'ipsec_enabled|saved IPsec service state' \
    'enc0_rule|saved encrypted-interface policy'; do
    key=${check%%|*}
    label=${check#*|}
    assert_flag "HQ $label" "$hq_saved" "$key"
    assert_flag "Branch $label" "$branch_saved" "$key"
done

hq_host_state=$(docker exec "$NATT_PREFIX-hq-host" sh -c \
    "ip -o -4 addr show dev eth1; ip -4 route show default" 2>/dev/null || true)
branch_host_state=$(docker exec "$NATT_PREFIX-branch-host" sh -c \
    "ip -o -4 addr show dev eth1; ip -4 route show default" 2>/dev/null || true)
if grep -qE 'inet 10\.10\.1\.10/24' <<<"$hq_host_state" \
    && grep -qE '^default via 10\.10\.1\.1 dev eth1([[:space:]]|$)' <<<"$hq_host_state"; then
    pass "HQ protected host scaffold is exact"
else
    fail "HQ protected host scaffold is exact" "incidental host state is inconsistent"
fi
if grep -qE 'inet 10\.20\.1\.10/24' <<<"$branch_host_state" \
    && grep -qE '^default via 10\.20\.1\.1 dev eth1([[:space:]]|$)' <<<"$branch_host_state"; then
    pass "Branch protected host scaffold is exact"
else
    fail "Branch protected host scaffold is exact" "incidental host state is inconsistent"
fi

nat_addresses=$(docker exec "$NATT_PREFIX-nat-cpe" ip -o -4 addr show 2>/dev/null || true)
if [[ "$(grep -Ec 'inet (198\.51\.100\.1|10\.200\.0\.1)/24' <<<"$nat_addresses" || true)" == 2 ]]; then
    pass "NAT boundary interface scaffold is exact"
else
    fail "NAT boundary interface scaffold is exact" "incidental NAT state is inconsistent"
fi

nat_rules=$(docker exec "$NATT_PREFIX-nat-cpe" iptables -t nat -S 2>/dev/null || true)
nat_user_rule_count=$(grep -c '^-A ' <<<"$nat_rules" || true)
nat_exact=true
grep -qE '^-A POSTROUTING -s 10\.200\.0\.0/24 -o eth1 .*--comment natt-lab-snat [^[:cntrl:]]*-j MASQUERADE$' \
    <<<"$nat_rules" || nat_exact=false
grep -qE '^-A PREROUTING -i eth1 -p udp .*--dport 500 .*--comment natt-lab-dnat-500 .*--to-destination 10\.200\.0\.2' \
    <<<"$nat_rules" || nat_exact=false
grep -qE '^-A PREROUTING -i eth1 -p udp .*--dport 4500 .*--comment natt-lab-dnat-4500 .*--to-destination 10\.200\.0\.2' \
    <<<"$nat_rules" || nat_exact=false
if [[ "$nat_exact" == true && "$nat_user_rule_count" == 3 ]]; then
    pass "NAT and port-forward inventory is exact"
else
    fail "NAT and port-forward inventory is exact" "incidental NAT state is inconsistent"
fi

forward_rules=$(docker exec "$NATT_PREFIX-nat-cpe" iptables -S FORWARD 2>/dev/null || true)
if [[ "$(grep -c '^-A FORWARD ' <<<"$forward_rules" || true)" == 0 ]] \
    && grep -qxF -- '-P FORWARD ACCEPT' <<<"$forward_rules"; then
    pass "NAT boundary has no armed or extra forwarding fault"
else
    fail "NAT boundary has no armed or extra forwarding fault" "forwarding policy is polluted or faulted"
fi

hq_before=$(natt_php "$NATT_HQ_PORT" hq "" "$lab_dir/grade-live.php" 2>/dev/null || true)
branch_before=$(natt_php "$NATT_BRANCH_PORT" branch "" "$lab_dir/grade-live.php" 2>/dev/null || true)

assert_remote_ping "HQ reaches its public underlay gateway" "$NATT_HQ_PORT" 198.51.100.1
assert_remote_ping "Branch reaches its private underlay gateway" "$NATT_BRANCH_PORT" 10.200.0.1
assert_remote_ping "Branch reaches the remote public peer through NAT" "$NATT_BRANCH_PORT" 198.51.100.2
assert_local_ping "HQ host reaches Branch host through IPsec" hq-host 10.20.1.10
assert_local_ping "Branch host reaches HQ host through IPsec" branch-host 10.10.1.10

hq_after=$(natt_php "$NATT_HQ_PORT" hq "" "$lab_dir/grade-live.php" 2>/dev/null || true)
branch_after=$(natt_php "$NATT_BRANCH_PORT" branch "" "$lab_dir/grade-live.php" 2>/dev/null || true)
for check in \
    'platform|live firewall platform' \
    'interfaces|live data-interface state' \
    'default_route|live default route' \
    'filter_rules|live policy activation' \
    'status_inventory|live SA inventory' \
    'ike|live IKEv2 state' \
    'natt|live NAT detection and UDP encapsulation' \
    'ike_crypto|live IKE algorithms' \
    'child|live CHILD state' \
    'child_crypto|live ESP algorithms' \
    'selectors|live protected selectors'; do
    key=${check%%|*}
    label=${check#*|}
    assert_flag "HQ $label" "$hq_after" "$key"
    assert_flag "Branch $label" "$branch_after" "$key"
done

hq_counter_before=$(sed -n 's/^packet_counter=//p' <<<"$hq_before")
hq_counter_after=$(sed -n 's/^packet_counter=//p' <<<"$hq_after")
branch_counter_before=$(sed -n 's/^packet_counter=//p' <<<"$branch_before")
branch_counter_after=$(sed -n 's/^packet_counter=//p' <<<"$branch_after")
if [[ "$hq_counter_before" =~ ^[0-9]+$ && "$hq_counter_after" =~ ^[0-9]+$ \
    && "$hq_counter_after" -gt "$hq_counter_before" ]]; then
    pass "HQ protected packet counters move"
else
    fail "HQ protected packet counters move" "counter evidence did not advance"
fi
if [[ "$branch_counter_before" =~ ^[0-9]+$ && "$branch_counter_after" =~ ^[0-9]+$ \
    && "$branch_counter_after" -gt "$branch_counter_before" ]]; then
    pass "Branch protected packet counters move"
else
    fail "Branch protected packet counters move" "counter evidence did not advance"
fi

summary
