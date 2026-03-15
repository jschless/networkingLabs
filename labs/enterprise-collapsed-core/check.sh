#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-collapsed-core"

check_contains "edge BGP Established" "$(eos edge 'show bgp summary')" "Estab"
check_contains "cc1 OSPF Full" "$(eos cc1 'show ip ospf neighbor')" "Full"
check_contains "cc2 OSPF Full" "$(eos cc2 'show ip ospf neighbor')" "Full"
check_ping_eos "client-a→client-b" client-a 10.20.20.11
check_ping_eos "client-b→client-a" client-b 10.10.10.11

summary
