#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "debug-dmvpn-phase1"

check_contains "hub NHRP entries" "$(eos hub 'show ip nhrp')" "172\.16\.0\."
check_contains "spoke1 OSPF Full" "$(eos spoke1 'show ip ospf neighbor')" "Full"
check_contains "spoke2 OSPF Full" "$(eos spoke2 'show ip ospf neighbor')" "Full"
check_contains "spoke3 OSPF Full" "$(eos spoke3 'show ip ospf neighbor')" "Full"
check_ping_eos "hub→spoke1 LAN" hub 192.168.1.1
check_ping_eos "hub→spoke2 LAN" hub 192.168.2.1
check_ping_eos "hub→spoke3 LAN" hub 192.168.3.1

summary
