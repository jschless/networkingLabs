#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "debug-eigrp-basics"

check_contains "r1 EIGRP neighbor" "$(frr r1 'show ip eigrp neighbors')" "10\.1\."
check_contains "r4 EIGRP neighbor" "$(frr r4 'show ip eigrp neighbors')" "10\.1\."
check_contains "r1 has route to r4 lo" "$(frr r1 'show ip route 10.0.0.4/32')" "10\.0\.0\.4"
check_ping_linux "r1→r4 loopback" r1 10.0.0.4
check_ping_linux "r4→r1 loopback" r4 10.0.0.1

summary
