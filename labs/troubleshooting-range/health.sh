#!/usr/bin/env bash
# Fast golden-state gate for the persistent troubleshooting range.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
P="clab-troubleshooting-range"
pass=0
fail=0

ok() { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s — %s\n' "$1" "$2"; fail=$((fail + 1)); }
frr() { docker exec "$P-$1" vtysh -c "$2" 2>/dev/null; }
eos() { docker exec "$P-$1" Cli -p 15 -c enable -c "$2" 2>/dev/null; }
node() { docker exec "$P-$1" sh -lc "$2" 2>/dev/null; }

[[ -f "$DIR/topology.clab.yml" ]] || exit 2
if ! docker ps --format '{{.Names}}' | grep -qx "$P-core1"; then
    echo "ERROR: range is not deployed"
    exit 2
fi

check_neighbors() {
    local type="$1" node_name="$2" expected="$3" out count
    if [[ "$type" == eos ]]; then out="$(eos "$node_name" 'show ip ospf neighbor')"
    else out="$(frr "$node_name" 'show ip ospf neighbor')"; fi
    count="$(printf '%s\n' "$out" | grep -Eic 'full' || true)"
    if [[ "$count" -ge "$expected" ]]; then ok "${node_name}: ${count}/${expected}+ OSPF neighbours full"
    else bad "${node_name}: OSPF adjacency" "expected ${expected}, got ${count}"; fi
}

check_ping() {
    local name="$1" from="$2" target="$3"
    if node "$from" "ping -c 1 -W 2 $target" >/dev/null; then ok "$name"
    else bad "$name" "ping from $from to $target failed"; fi
}

echo "=== Troubleshooting Range health gate ==="
check_neighbors eos acc1 2
check_neighbors eos acc2 2
check_neighbors frr core1 4
check_neighbors frr core2 5
check_neighbors frr edge 2
check_neighbors frr branch1 1
check_ping "corp reaches branch client" corp1 10.250.50.10
check_ping "guest reaches internet-test endpoint" guest1 198.18.0.10
check_ping "branch reaches services" branch-client 10.250.40.10
check_ping "branch reaches voice endpoint" branch-client 10.250.20.10

core_mtu="$(node core1 "cat /sys/class/net/eth3/mtu" || true)"
if [[ "$core_mtu" == 1500 ]]; then
    ok "core1/core2 transit MTU is 1500"
else
    bad "core1/core2 transit MTU" "expected 1500, got ${core_mtu:-unknown}"
fi

service_route="$(eos acc1 'show ip route 10.250.40.10' || true)"
if [[ "$service_route" == *'via 10.250.0.0, Ethernet1'* ]]; then
    ok "corporate access uses the primary services path"
else
    bad "corporate services path" "expected next hop 10.250.0.0 on Ethernet1"
fi

dns_output="$(node corp1 'timeout 3 nslookup web.range.test 10.250.40.10' || true)"
if [[ "$dns_output" == *'10.250.40.10'* ]]; then
    ok "corp resolves web.range.test through range DNS"
else
    bad "corp DNS resolution" "web.range.test did not resolve"
fi
if node corp1 'python3 -c "import socket; socket.create_connection((\"10.250.40.10\", 8080), 2).close()"'; then
    ok "corp opens TCP/8080 to web service"
else
    bad "corp web reachability" "TCP/8080 connection failed"
fi

voice_dns="$(node voice1 'timeout 3 getent ahostsv4 web.range.test' || true)"
if [[ "$voice_dns" == *'10.250.40.10'* ]]; then
    ok "voice resolves web.range.test through configured DNS"
else
    bad "voice DNS resolution" "configured resolver did not return 10.250.40.10"
fi
if node voice1 'python3 -c "import socket; socket.create_connection((\"10.250.40.10\", 8080), 2).close()"'; then
    ok "voice opens TCP/8080 to web service"
else
    bad "voice web reachability" "TCP/8080 connection failed"
fi

echo "Results: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
