#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "evpn-border-ceos"

check_contains "leaf1 BGP Established" "$(eos leaf1 'show bgp summary')" "Estab"
check_contains "bleaf1 BGP Established" "$(eos bleaf1 'show bgp summary')" "Estab"
check_contains "bleaf1→ext-router Established" "$(eos bleaf1 'show bgp summary')" "Estab"
# TENANT-A intra-fabric
check_ping_eos "host-a1→host-a2" host-a1 10.10.10.12
check_ping_eos "host-a2→host-a1" host-a2 10.10.10.11
# TENANT-B isolation (still separate)
check_ping_eos "host-b1→host-b2" host-b1 10.20.20.12
check_no_ping_eos "host-a1 cannot reach TENANT-B" host-a1 10.20.20.11
# Type-5 external route visible in TENANT-A on bleaf1
check_contains "bleaf1 type-5 route" "$(eos bleaf1 'show bgp evpn route-type ip-prefix ipv4')" "RD"

summary
