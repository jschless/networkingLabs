#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "spine-leaf"

check_contains "leaf1 BGP Established" "$(eos leaf1 'show bgp summary')" "Estab"
check_contains "leaf2 BGP Established" "$(eos leaf2 'show bgp summary')" "Estab"
check_contains "leaf3 BGP Established" "$(eos leaf3 'show bgp summary')" "Estab"
check_contains "leaf4 BGP Established" "$(eos leaf4 'show bgp summary')" "Estab"
check_contains "spine1 BGP Established" "$(eos spine1 'show bgp summary')" "Estab"
check_contains "ECMP paths on leaf1" "$(eos leaf1 'show ip route 10.0.0.4/32')" "via"
check_ping_eos "leaf1→leaf4 loopback" leaf1 10.0.0.4 10.0.0.1
check_ping_eos "leaf4→leaf1 loopback" leaf4 10.0.0.1 10.0.0.4

summary
