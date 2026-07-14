#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-campus
passed=0 failed=0
ok() { printf '  PASS %s\n' "$1"; passed=$((passed + 1)); }
bad() { printf '  FAIL %s — %s\n' "$1" "$2"; failed=$((failed + 1)); }
node() { docker exec "$P-$1" sh -lc "$2"; }
eos() { docker exec "$P-$1" Cli -p 15 -c enable -c "$2"; }

check_ping() {
    local label=$1 source=$2 target=$3
    if node "$source" "ping -c 2 -W 1 $target" >/dev/null 2>&1; then ok "$label"; else bad "$label" "ping to $target failed"; fi
}

echo '=== Campus Troubleshooting Range health gate ==='
for sw in dist1 acc1; do
    summary="$(eos "$sw" 'show lacp peer' || true)"
    if grep -Eq 'Et1[[:space:]]+Bundled' <<<"$summary" && grep -Eq 'Et2[[:space:]]+Bundled' <<<"$summary"; then ok "$sw LACP bundle has two forwarding members"; else bad "$sw LACP bundle" 'both Et1 and Et2 must be bundled'; fi
done

root="$(eos dist1 'show spanning-tree vlan 10' || true)"
if [[ "$root" == *'This bridge is the root'* ]]; then ok 'dist1 is the VLAN 10 STP root'; else bad 'VLAN 10 STP root' 'dist1 is not root'; fi

edge_status="$(eos acc1 'show interfaces status' || true)"
if [[ "$edge_status" != *'Et5'*errdisabled* ]]; then ok 'protected rogue edge is not errdisabled'; else bad 'protected rogue edge' 'Ethernet5 is errdisabled'; fi

check_ping 'corporate endpoint reaches its gateway' campus1 10.252.10.1
check_ping 'voice endpoint reaches its gateway' voice1 10.252.20.1
check_ping 'corporate endpoint reaches voice endpoint' campus1 10.252.20.10
check_ping 'voice endpoint reaches corporate endpoint' voice1 10.252.10.10
if node dhcp1 "ss -lun '( sport = :67 )' | grep -q ':67'" >/dev/null 2>&1; then ok 'DHCP service is listening on UDP/67'; else bad 'DHCP service' 'dnsmasq is not listening on UDP/67'; fi

printf 'Results: %d passed, %d failed\n' "$passed" "$failed"
[[ $failed -eq 0 ]]
