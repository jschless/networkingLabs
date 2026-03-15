#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "ospf-auth"

check_contains "r1-r2 OSPF Full" "$(eos r1 'show ip ospf neighbor')" "Full"
check_contains "r2-r3 OSPF Full" "$(eos r2 'show ip ospf neighbor')" "Full"
check_ping_eos "r1→r3 loopback" r1 10.0.0.3 10.0.0.1
check_ping_eos "r3→r1 loopback" r3 10.0.0.1 10.0.0.3

summary
