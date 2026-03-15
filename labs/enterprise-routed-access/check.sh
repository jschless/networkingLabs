#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-routed-access"

check_contains "core1 OSPF Full" "$(eos core1 'show ip ospf neighbor')" "Full"
check_contains "core2 OSPF Full" "$(eos core2 'show ip ospf neighbor')" "Full"
check_contains "dist1 OSPF Full" "$(eos dist1 'show ip ospf neighbor')" "Full"
check_ping_eos "h1→h3 cross-access" h1 10.10.2.2
check_ping_eos "h3→h1 cross-access" h3 10.10.1.2

summary
