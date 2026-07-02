#!/usr/bin/env bash
# Asserts the baseline the assurance exercises depend on.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "network-assurance"

nsh() { docker exec "clab-${TOPO_NAME}-$1" sh -c "$2" 2>/dev/null; }

check_contains "r1 OSPF neighbor Full" "$(frr r1 'show ip ospf neighbor')" "Full"
check_contains "r2 OSPF neighbor Full" "$(frr r2 'show ip ospf neighbor')" "Full"
check_ping_linux "client→server across the core" client 10.3.0.2
check_contains "snmpd running on r1" "$(nsh r1 'pgrep -a snmpd')" "snmpd"

summary
