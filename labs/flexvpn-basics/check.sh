#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "flexvpn-basics"

check_contains "gw-a IKEv2 ESTABLISHED" "$(node gw-a 'ipsec status')" "ESTABLISHED"
check_contains "gw-b IKEv2 ESTABLISHED" "$(node gw-b 'ipsec status')" "ESTABLISHED"
check_contains "gw-c IKEv2 ESTABLISHED" "$(node gw-c 'ipsec status')" "ESTABLISHED"
check_ping_linux "host-a→host-b" host-a 192.168.2.10
check_ping_linux "host-a→host-c" host-a 192.168.3.10

summary
