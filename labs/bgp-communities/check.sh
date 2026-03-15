#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "bgp-communities"

check_contains "r1 BGP Established" "$(eos r1 'show bgp summary')" "Estab"
check_contains "r2 BGP Established" "$(eos r2 'show bgp summary')" "Estab"
check_contains "r3 BGP Established" "$(eos r3 'show bgp summary')" "Estab"
# Community should be present on r2's route from r1
check_contains "community on r2" "$(eos r2 'show bgp ipv4 unicast 10.0.0.1/32 detail')" "Community"
check_ping_eos "r1→r4 loopback" r1 10.0.0.4 10.0.0.1
check_ping_eos "r4→r1 loopback" r4 10.0.0.1 10.0.0.4

summary
