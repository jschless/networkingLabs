#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "lacp-etherchannel"

check_contains "sw1 Port-Channel1 up" "$(eos sw1 'show interfaces Port-Channel1')" "is up"
check_contains "sw2 Port-Channel1 up" "$(eos sw2 'show interfaces Port-Channel1')" "is up"
check_contains "sw1 LACP active" "$(eos sw1 'show lacp interface Port-Channel1')" "Active"
check_ping_eos "host1→host2" host1 10.0.1.2
check_ping_eos "host2→host1" host2 10.0.1.1

summary
