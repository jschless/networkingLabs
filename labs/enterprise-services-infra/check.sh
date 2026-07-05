#!/usr/bin/env bash
# Asserts the SOLVED end state — run after completing the README exercises
# (DHCP relay, TACACS+, NTP/syslog pointed at services1).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-services-infra"

nsh() { docker exec "clab-${TOPO_NAME}-$1" sh -c "$2" 2>/dev/null; }

check_contains "services1 dnsmasq (DHCP) running" \
  "$(nsh services1 'pgrep -a dnsmasq')" "dnsmasq"
check_contains "campus1 Vlan10 relays DHCP to services1" \
  "$(eos campus1 'show running-config interfaces Vlan10')" "helper-address 192\.168\.99\.10"
check_contains "campus1 TACACS server configured" \
  "$(eos campus1 'show running-config section tacacs')" "192\.168\.99\.20"
check_contains "campus1 NTP points at services1" \
  "$(eos campus1 'show running-config section ntp')" "192\.168\.99\.10"
check_contains "campus1 syslog points at services1" \
  "$(eos campus1 'show running-config section logging')" "192\.168\.99\.10"

summary
