#!/usr/bin/env bash
# Asserts the SOLVED end state — run after completing the README tasks.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "campus-l2-hardening"

check_contains "dist1 is STP root for VLAN 10" \
  "$(eos dist1 'show spanning-tree vlan 10')" "This bridge is the root"
check_contains "acc1 Et2 has portfast" \
  "$(eos acc1 'show running-config interfaces Ethernet2')" "portfast"
check_contains "acc1 Et2 has BPDU guard" \
  "$(eos acc1 'show running-config interfaces Ethernet2')" "bpduguard enable"
check_contains "acc1 Et3 has root guard" \
  "$(eos acc1 'show running-config interfaces Ethernet3')" "guard root"
check_ping_linux "client-a→gateway" client-a 10.10.10.1

summary
