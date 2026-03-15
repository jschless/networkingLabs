#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "stp-operations"

check_contains "cc1 STP root VLAN10" "$(eos cc1 'show spanning-tree vlan 10')" "This bridge is the root"
check_contains "STP convergence complete" "$(eos acc1 'show spanning-tree')" "forwarding"
check_ping_eos "client-a→cc1 gateway" client-a 10.10.10.1
check_ping_linux "client-a→cc1 gateway via shell" client-a 10.10.10.1

summary
