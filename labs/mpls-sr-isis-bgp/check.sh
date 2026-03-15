#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "mpls-sr-isis-bgp"

check_contains "pe1 IS-IS Up" "$(frr pe1 'show isis neighbor')" "Up"
check_contains "pe2 IS-IS Up" "$(frr pe2 'show isis neighbor')" "Up"
check_contains "pe1 SR label table" "$(frr pe1 'show mpls table')" "16001"
check_contains "pe1 BGP Established" "$(frr pe1 'show bgp summary')" "Established"
check_contains "pe2 BGP Established" "$(frr pe2 'show bgp summary')" "Established"
check_contains "pe1 VRF route" "$(frr pe1 'show bgp vrf CUST-A ipv4 unicast')" "192\.168\."
check_ping_linux "ce1→ce2" ce1 192.168.20.1
check_ping_linux "ce2→ce1" ce2 192.168.10.1

summary
