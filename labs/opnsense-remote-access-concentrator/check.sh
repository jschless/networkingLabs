#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "opnsense-remote-access-concentrator"
check_contains "developer WireGuard interface exists" "$(node developer 'ip link show wg0 2>/dev/null || true')" "wg0"
check_contains "contractor WireGuard interface exists" "$(node contractor 'ip link show wg0 2>/dev/null || true')" "wg0"
check_contains "developer reaches corp application" "$(node developer 'nc -w3 10.70.10.10 8443 || true')" "corp application"
check_contains "developer reaches jump host" "$(node developer 'nc -w3 10.70.10.20 22 || true')" "jump host"
check_contains "contractor reaches jump host" "$(node contractor 'nc -w3 10.70.10.20 22 || true')" "jump host"
if node contractor 'nc -z -w3 10.70.10.10 8443'; then
  fail "contractor cannot reach corp application" "TCP/8443 unexpectedly succeeded from contractor"
else
  pass "contractor cannot reach corp application"
fi
summary
