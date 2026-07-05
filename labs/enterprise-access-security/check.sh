#!/usr/bin/env bash
# Asserts the SOLVED end state — run after completing the README tasks
# (DHCP snooping with a trusted uplink, edge protections applied).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-access-security"

check_contains "acc1 DHCP snooping enabled" \
  "$(eos acc1 'show ip dhcp snooping')" "nabled"
check_contains "acc1 has a snooping binding for client-a" \
  "$(eos acc1 'show ip dhcp snooping binding')" "10\.10\.10\."
check_ping_linux "client-a→gateway (10.10.10.2)" client-a 10.10.10.2

summary
