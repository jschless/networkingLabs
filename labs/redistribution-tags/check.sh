#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "redistribution-tags"

check_contains "asbr1 EIGRP neighbor" "$(frr asbr1 'show ip eigrp neighbors')" "10\.2\."
check_contains "asbr2 EIGRP neighbor" "$(frr asbr2 'show ip eigrp neighbors')" "10\.2\."
check_contains "r3 has r1 route" "$(frr r3 'show ip route 10.0.0.1/32')" "10\.0\.0\.1"
check_contains "r1 has r3 route" "$(frr r1 'show ip route 10.0.0.5/32')" "10\.0\.0\.5"
check_ping_linux "r1→r3 loopback" r1 10.0.0.5
check_ping_linux "r3→r1 loopback" r3 10.0.0.1

summary
