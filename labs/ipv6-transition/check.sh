#!/usr/bin/env bash
# Asserts the SOLVED end state of the 6PE core — run after the README tasks.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "ipv6-transition"

check_contains "pe1 IS-IS adjacency up" "$(frr pe1 'show isis neighbor')" "Up"
check_contains "pe1 BGP sessions established" "$(frr pe1 'show bgp summary')" "Established"
check_contains "pe1 has SR labels in the MPLS table" "$(frr pe1 'show mpls table')" "16001|16002|16003|SR"
check_contains "pe2 learned ce1's prefix via 6PE" \
  "$(frr pe2 'show bgp ipv6 labeled-unicast')" "fd00:1::/48"

if docker exec "clab-${TOPO_NAME}-ce1" ping -6 -c3 -W2 fd00:2::1 &>/dev/null
then pass "ce1→ce2 across the 6PE core"
else fail "ce1→ce2 across the 6PE core" "ping fd00:2::1 failed from ce1"; fi

summary
