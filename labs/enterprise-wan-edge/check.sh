#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-wan-edge"

check_contains "edge BGP Established isp1" "$(eos edge 'show bgp summary')" "Estab"
check_contains "core1 OSPF Full" "$(eos core1 'show ip ospf neighbor')" "Full"
check_contains "edge advertises prefix" "$(eos edge 'show bgp ipv4 unicast')" "198\.51\.100"
check_ping_linux "server→isp1" server 10.0.1.1
check_ping_linux "server→isp2" server 10.0.2.1

summary
