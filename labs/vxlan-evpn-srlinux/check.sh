#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "vxlan-evpn-srlinux"

check_contains "vtep1 OSPF Full" "$(srl vtep1 'show network-instance default protocols ospf neighbor')" "full"
check_contains "vtep2 OSPF Full" "$(srl vtep2 'show network-instance default protocols ospf neighbor')" "full"
check_contains "vtep1 BGP Established" "$(srl vtep1 'show network-instance default protocols bgp neighbor')" "established"
check_contains "vtep2 BGP Established" "$(srl vtep2 'show network-instance default protocols bgp neighbor')" "established"
check_ping_linux "host1→host2" host1 172.16.0.2
check_ping_linux "host2→host1" host2 172.16.0.1

summary
