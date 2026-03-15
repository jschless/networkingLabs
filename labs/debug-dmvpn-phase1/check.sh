#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "debug-dmvpn-phase1"

check_contains "hub NHRP missing broken spoke1" "$(vyos_frr hub 'show ip nhrp')" "172\.16\.0\.12|172\.16\.0\.13"
check_not_contains "hub NHRP omits spoke1" "$(vyos_frr hub 'show ip nhrp')" "172\.16\.0\.11"
check_not_contains "hub OSPF omits spoke1" "$(vyos_frr hub 'show ip ospf neighbor')" "172\.16\.0\.11"
check_contains "hub still sees spoke2 OSPF Full" "$(vyos_frr hub 'show ip ospf neighbor')" "172\.16\.0\.12"
check_contains "hub still sees spoke3 OSPF Full" "$(vyos_frr hub 'show ip ospf neighbor')" "172\.16\.0\.13"
check_no_ping_vyos "hub cannot reach spoke1 LAN" hub 192.168.1.1
check_ping_vyos "hub→spoke2 LAN" hub 192.168.2.1
check_ping_vyos "hub→spoke3 LAN" hub 192.168.3.1

summary
