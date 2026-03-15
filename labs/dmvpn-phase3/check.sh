#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "dmvpn-phase3"

check_contains "hub NHRP entries" "$(frr hub 'show ip nhrp')" "172\.16\.0\."
check_contains "spoke1 OSPF neighbor" "$(frr spoke1 'show ip ospf neighbor')" "Full"
check_ping_linux "hub→spoke1 LAN" hub 192.168.1.1
check_ping_linux "hub→spoke3 LAN" hub 192.168.3.1
check_ping_linux "spoke1→spoke2 LAN" spoke1 192.168.2.1
check_ping_linux "spoke2→spoke3 LAN" spoke2 192.168.3.1

summary
