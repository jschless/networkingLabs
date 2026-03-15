#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "mpls-sr-srlinux"

check_contains "pe1 IS-IS Up" "$(srl pe1 'show network-instance default protocols isis adjacency')" "Up"
check_contains "pe2 IS-IS Up" "$(srl pe2 'show network-instance default protocols isis adjacency')" "Up"
check_contains "pe1 BGP Established" "$(srl pe1 'show network-instance default protocols bgp neighbor')" "established"
check_contains "pe1 route to pe2" "$(srl pe1 'show network-instance default route-table ipv4-unicast prefix 10.0.0.3/32')" "10\.0\.0\.3"
check_ping_linux "ce1→ce2" ce1 192.168.20.1
check_ping_linux "ce2→ce1" ce2 192.168.10.1

summary
