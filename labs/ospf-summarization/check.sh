#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "ospf-summarization"

check_contains "r1-r2 OSPF Full" "$(eos r1 'show ip ospf neighbor')" "Full"
check_contains "r2-r3 OSPF Full" "$(eos r2 'show ip ospf neighbor')" "Full"
# r1 should see summary prefix from area 1 (10.1.0.0/22 or similar)
check_contains "r4 OSPF Full" "$(eos r4 'show ip ospf neighbor')" "Full"
check_ping_eos "r1→r4" r1 10.2.0.1 10.1.1.1
check_ping_eos "r4→r1" r4 10.1.1.1 10.2.0.1

summary
