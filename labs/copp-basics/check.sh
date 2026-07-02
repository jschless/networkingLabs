#!/usr/bin/env bash
# Asserts the SOLVED end state — run after completing the README tasks.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "copp-basics"

check_contains "r2 eBGP to r1 Established" "$(eos r2 'show bgp summary')" "Estab"
check_contains "r2 OSPF to r3 FULL" "$(eos r2 'show ip ospf neighbor')" "FULL"
check_contains "r2 CoPP class CLASS-BGP present" \
  "$(eos r2 'show policy-map type copp')" "CLASS-BGP"
check_contains "r2 CoPP class CLASS-OSPF present" \
  "$(eos r2 'show policy-map type copp')" "CLASS-OSPF"
check_ping_eos "r1→r2 loopback" r1 10.0.0.2 10.0.0.1

summary
