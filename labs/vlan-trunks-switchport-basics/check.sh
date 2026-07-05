#!/usr/bin/env bash
# Asserts the SOLVED end state — run after completing the README tasks
# (access ports, trunk carrying VLANs 10 and 20).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "vlan-trunks-switchport-basics"

check_contains "sw1 trunk carries VLAN 10" "$(eos sw1 'show interfaces trunk')" "10"
check_contains "sw1 Et1 is an access port" \
  "$(eos sw1 'show running-config interfaces Ethernet1')" "switchport access vlan"
check_ping_linux "host-a→host-b (VLAN 10 across trunk)" host-a 10.10.10.12
check_ping_linux "voice-a→voice-b (VLAN 20 across trunk)" voice-a 10.20.20.12
check_no_ping_linux "host-a cannot reach VLAN 20" host-a 10.20.20.12

summary
