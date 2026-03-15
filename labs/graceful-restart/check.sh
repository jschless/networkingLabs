#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "graceful-restart"

check_contains "r1 BGP Established" "$(eos r1 'show bgp summary')" "Estab"
check_contains "r3 BGP Established" "$(eos r3 'show bgp summary')" "Estab"
check_contains "r1 learns r3 service route" "$(eos r1 'show bgp ipv4 unicast 172.16.3.1/32')" "172\\.16\\.3\\.1/32"
check_contains "r3 learns r1 service route" "$(eos r3 'show bgp ipv4 unicast 172.16.1.1/32')" "172\\.16\\.1\\.1/32"
check_ping_eos "r1→r3 service route" r1 172.16.3.1 172.16.1.1
check_ping_eos "r3→r1 service route" r3 172.16.1.1 172.16.3.1

summary
