#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "bgp-prefix-security"

check_contains "legitimate BGP Established" "$(eos legitimate 'show bgp summary')" "Estab"
check_contains "isp BGP Established" "$(eos isp 'show bgp summary')" "Estab"
# victim should see legitimate's 192.0.2.0/24 but NOT hijacker's /25
check_contains "victim has legitimate prefix" "$(eos victim 'show bgp ipv4 unicast 192.0.2.0/24')" "65001"
check_not_contains "victim no hijacker route" "$(eos victim 'show bgp ipv4 unicast 192.0.2.128/25')" "65002"

summary
