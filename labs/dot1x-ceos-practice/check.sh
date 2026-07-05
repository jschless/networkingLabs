#!/usr/bin/env bash
# Asserts the SOLVED end state — run after completing the README tasks
# (dot1x configured on access1 and the supplicants authenticated).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "dot1x-ceos-practice"

check_contains "access1 RADIUS server configured" \
  "$(eos access1 'show running-config section radius-server')" "192\.168\.100\.2"
check_contains "access1 dot1x enabled globally" \
  "$(eos access1 'show running-config all | section dot1x')" "system-auth-control"
check_contains "access1 Et1 is an authenticator" \
  "$(eos access1 'show running-config interfaces Ethernet1')" "dot1x pae authenticator"
check_contains "access1 Et1 port-control auto" \
  "$(eos access1 'show running-config interfaces Ethernet1')" "dot1x port-control auto"

check_ping_linux    "supplicant-tls→employee-server (VLAN 10)"    supplicant-tls  10.10.10.1
check_ping_linux    "supplicant-peap→contractor-server (VLAN 20)" supplicant-peap 10.20.20.1
check_no_ping_linux "supplicant-fail blocked from VLAN 10"        supplicant-fail 10.10.10.1

summary
