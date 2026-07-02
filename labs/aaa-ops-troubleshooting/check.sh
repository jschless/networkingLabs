#!/usr/bin/env bash
# Asserts the SOLVED end state — run after completing the README tasks
# (TACACS+ login configured on device1, tac_plus healthy).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "aaa-ops-troubleshooting"

nsh() { docker exec "clab-${TOPO_NAME}-$1" sh -c "$2" 2>/dev/null; }

check_contains "device1 has TACACS server configured" \
  "$(eos device1 'show running-config section tacacs')" "192\.168\.99\.20"
check_contains "device1 AAA login uses TACACS with local fallback" \
  "$(eos device1 'show running-config section aaa')" \
  "aaa authentication login default group tacacs\+ local"
check_contains "tac_plus running on tacacs1" \
  "$(nsh tacacs1 'pgrep -a tac_plus')" "tac_plus"

if docker exec "clab-${TOPO_NAME}-admin1" nc -zw3 192.168.99.1 22 &>/dev/null
then pass "admin1 can reach device1 SSH (192.168.99.1:22)"
else fail "admin1 can reach device1 SSH (192.168.99.1:22)" "TCP/22 not reachable"; fi

summary
