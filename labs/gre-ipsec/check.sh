#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "gre-ipsec"

check_contains "gw-a IPsec ESTABLISHED" "$(node gw-a 'ipsec status')" "ESTABLISHED"
check_contains "gw-b IPsec ESTABLISHED" "$(node gw-b 'ipsec status')" "ESTABLISHED"
check_contains "gw-a xfrm SAs" "$(node gw-a 'ip xfrm state')" "src"
check_ping_linux "host-a→host-b" host-a 192.168.2.10
check_ping_linux "host-b→host-a" host-b 192.168.1.10

summary
