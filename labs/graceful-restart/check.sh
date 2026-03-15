#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "graceful-restart"

check_contains "r1 OSPF Full" "$(frr r1 'show ip ospf neighbor')" "Full"
check_contains "r2 OSPF Full" "$(frr r2 'show ip ospf neighbor')" "Full"
check_contains "r1 BGP Established" "$(frr r1 'show bgp summary')" "Established"
check_contains "r2 BGP Established" "$(frr r2 'show bgp summary')" "Established"
check_ping_linux "r1→r3 loopback" r1 10.0.0.3
check_ping_linux "r3→r1 loopback" r3 10.0.0.1

summary
