#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "ospf-default-route"

check_contains "core-asbr OSPF Full" "$(eos core 'show ip ospf neighbor')" "Full"
check_contains "core has default route" "$(eos core 'show ip route 0.0.0.0/0')" "0.0.0.0/0"
check_ping_eos "core→internet" core 10.99.0.1 10.0.0.1

summary
