#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "ospf-virtual-link"

check_contains "r1-r2 OSPF Full" "$(eos r1 'show ip ospf neighbor')" "Full"
check_contains "r2-r3 virtual link Full" "$(eos r2 'show ip ospf neighbor')" "Full"
check_contains "r3-r4 OSPF Full" "$(eos r3 'show ip ospf neighbor')" "Full"
check_ping_eos "r1→r4 loopback" r1 10.0.0.4 10.0.0.1
check_ping_eos "r4→r1 loopback" r4 10.0.0.1 10.0.0.4

summary
