#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "debug-vxlan-evpn"

check_contains "vtep1 OSPF Full" "$(frr vtep1 'show ip ospf neighbor')" "Full"
check_contains "vtep2 OSPF Full" "$(frr vtep2 'show ip ospf neighbor')" "Full"
check_contains "vtep1 BGP Established" "$(frr vtep1 'show bgp summary')" "Established"
check_ping_linux "host1→host2" host1 172.16.0.2
check_ping_linux "host2→host1" host2 172.16.0.1

summary
