#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "bgp-filtering"

check_contains "r1 BGP Established" "$(eos r1 'show bgp summary')" "Estab"
check_contains "r2 BGP Established" "$(eos r2 'show bgp summary')" "Estab"
check_contains "r3 BGP Established" "$(eos r3 'show bgp summary')" "Estab"
# r4 should see r1's loopback but NOT 172.16.2.0/24 (filtered)
check_contains "r4 has r1 loopback" "$(eos r4 'show bgp ipv4 unicast 10.0.0.1/32')" "10\.0\.0\.1"
check_not_contains "r4 filtered 172.16.2.0" "$(eos r4 'show bgp ipv4 unicast')" "172\.16\.2\.0"
check_ping_eos "r1→r4 loopback" r1 10.0.0.4 10.0.0.1

summary
