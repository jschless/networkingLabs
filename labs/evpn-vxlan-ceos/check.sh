#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "evpn-vxlan-ceos"

check_contains "leaf1 BGP Established" "$(eos leaf1 'show bgp summary')" "Estab"
check_contains "leaf3 BGP Established" "$(eos leaf3 'show bgp summary')" "Estab"
check_contains "leaf1 VTEP populated" "$(eos leaf1 'show vxlan vtep')" "10\.0\.0\."
# TENANT-A
check_ping_eos "host-a1→host-a2" host-a1 10.10.10.12
check_ping_eos "host-a2→host-a1" host-a2 10.10.10.11
# TENANT-B
check_ping_eos "host-b1→host-b2" host-b1 10.20.20.12
check_ping_eos "host-b2→host-b1" host-b2 10.20.20.11
# Cross-tenant isolation
check_no_ping_eos "host-a1 cannot reach TENANT-B" host-a1 10.20.20.11

summary
