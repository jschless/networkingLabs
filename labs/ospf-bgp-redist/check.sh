#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "ospf-bgp-redist"

check_contains "r1-asbr OSPF Full" "$(eos r1 'show ip ospf neighbor')" "Full"
check_contains "asbr BGP Established" "$(eos asbr 'show bgp summary')" "Estab"
check_contains "bgp1 BGP Established" "$(eos bgp1 'show bgp summary')" "Estab"
check_ping_eos "r1→bgp2 loopback" r1 10.0.0.4 10.0.0.1
check_ping_eos "bgp2→r1 loopback" bgp2 10.0.0.1 10.0.0.4

summary
