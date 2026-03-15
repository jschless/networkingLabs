#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-wan-edge-capstone"

check_contains "edge BGP Established" "$(eos edge 'show bgp summary')" "Estab"
check_contains "core1 OSPF Full" "$(eos core1 'show ip ospf neighbor')" "Full"
check_contains "edge advertises prefix" "$(eos edge 'show bgp ipv4 unicast')" "198\.51\.100"

summary
