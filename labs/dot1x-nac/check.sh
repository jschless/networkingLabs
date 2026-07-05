#!/usr/bin/env bash
# Asserts the SOLVED end state — run after the supplicants have authenticated.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "dot1x-nac"

nsh() { docker exec "clab-${TOPO_NAME}-$1" sh -c "$2" 2>/dev/null; }

check_contains "freeradius running on radius" \
  "$(nsh radius 'pgrep -a radiusd || pgrep -a freeradius')" "radius"
check_contains "hostapd running on authenticator" \
  "$(nsh authenticator 'pgrep -a hostapd')" "hostapd"

check_ping_linux    "supplicant-tls→employee-server (VLAN 10)"  supplicant-tls  10.10.10.1
check_no_ping_linux "supplicant-tls blocked from VLAN 20"       supplicant-tls  10.20.20.1
check_ping_linux    "supplicant-peap→contractor-server (VLAN 20)" supplicant-peap 10.20.20.1
check_no_ping_linux "supplicant-fail quarantined"               supplicant-fail 10.10.10.1

summary
