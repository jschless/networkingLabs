#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "dmvpn-phase1"

check_contains "hub NHRP entries" "$(vyos_frr hub 'show ip nhrp')" "172\.16\.0\."
check_contains "hub sees spoke1 OSPF Full" "$(vyos_frr hub 'show ip ospf neighbor')" "Full/.+172\.16\.0\.11"
check_contains "hub sees spoke2 OSPF Full" "$(vyos_frr hub 'show ip ospf neighbor')" "Full/.+172\.16\.0\.12"
check_contains "hub sees spoke3 OSPF Full" "$(vyos_frr hub 'show ip ospf neighbor')" "Full/.+172\.16\.0\.13"
check_ping_vyos "hub→spoke1 LAN" hub 192.168.1.1
check_ping_vyos "hub→spoke2 LAN" hub 192.168.2.1
check_ping_vyos "hub→spoke3 LAN" hub 192.168.3.1

summary
