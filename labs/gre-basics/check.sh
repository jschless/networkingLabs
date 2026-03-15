#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "gre-basics"

check_contains "gw-a tun0 up" "$(node gw-a 'ip link show tun0')" "UP"
check_contains "gw-b tun0 up" "$(node gw-b 'ip link show tun0')" "UP"
check_ping_linux "gw-a→gw-b tunnel" gw-a 172.16.0.2
check_ping_linux "host-a→host-b" host-a 192.168.2.10

summary
