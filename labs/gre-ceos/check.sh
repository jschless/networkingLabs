#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "gre-ceos"

check_contains "gw-a Tunnel0 up" "$(eos gw-a 'show interfaces Tunnel0')" "is up"
check_contains "gw-b Tunnel0 up" "$(eos gw-b 'show interfaces Tunnel0')" "is up"
check_ping_eos "gw-a→gw-b tunnel" gw-a 172.16.0.2
check_ping_linux "host-a→host-b" host-a 192.168.2.10

summary
