#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "wireguard"

check_contains "hub wg0 peers" "$(node hub 'wg show wg0')" "peer"
check_contains "gw-a wg0 up" "$(node gw-a 'ip link show wg0')" "UP"
check_contains "gw-b wg0 up" "$(node gw-b 'ip link show wg0')" "UP"
check_ping_linux "hub→gw-a tunnel" hub 192.168.100.10
check_ping_linux "hub→gw-b tunnel" hub 192.168.100.20
check_ping_linux "gw-a→hub tunnel" gw-a 192.168.100.1
check_ping_linux "gw-b→hub tunnel" gw-b 192.168.100.1

summary
