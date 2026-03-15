#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "bgp-aggregation"

check_contains "originator BGP Established" "$(eos originator 'show bgp summary')" "Estab"
check_contains "aggregator BGP Established" "$(eos aggregator 'show bgp summary')" "Estab"
# receiver should see the aggregate, not the specifics
check_contains "receiver has aggregate" "$(eos receiver 'show bgp ipv4 unicast')" "10\.1\.0\.0/21"
check_not_contains "receiver no /24 specifics" "$(eos receiver 'show bgp ipv4 unicast')" "10\.1\.1\.0/24"
check_ping_eos "originator→receiver" originator 10.0.0.3 10.0.0.1
check_ping_eos "receiver→originator" receiver 10.0.0.1 10.0.0.3

summary
