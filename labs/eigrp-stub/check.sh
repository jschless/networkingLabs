#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "eigrp-stub"

check_contains "hub-spoke1 EIGRP neighbor" "$(frr hub 'show ip eigrp neighbors')" "10\.1\.11\."
check_contains "hub-spoke2 EIGRP neighbor" "$(frr hub 'show ip eigrp neighbors')" "10\.1\.12\."
check_contains "hub-spoke3 EIGRP neighbor" "$(frr hub 'show ip eigrp neighbors')" "10\.1\.13\."
check_contains "hub has route to ce" "$(frr hub 'show ip route 10.0.0.5/32')" "10\.0\.0\.5"
check_ping_linux "hub→ce loopback" hub 10.0.0.5
check_ping_linux "ce→hub loopback" ce 10.0.0.1

summary
