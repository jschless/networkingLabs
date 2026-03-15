#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "mpls-l2vpn"

check_contains "pe1 IS-IS Up" "$(frr pe1 'show isis neighbor')" "Up"
check_contains "pe1 LDP session" "$(frr pe1 'show mpls ldp neighbor')" "OPERATIONAL"
check_contains "pe1 pseudowire" "$(frr pe1 'show l2vpn atom vc')" "UP"
check_ping_linux "ce1→ce2" ce1 10.100.0.2
check_ping_linux "ce2→ce1" ce2 10.100.0.1

summary
