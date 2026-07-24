#!/usr/bin/env bash
# End-state checks for the provider-neutral orchestrated WAN overlay.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init orchestrated-wan-overlay

BREAK_IT="${1:-}"

for edge in hub branch1 branch2; do
  check_contains "$edge has trusted unexpired identity" "$(node "$edge" "openssl verify -CAfile /runtime/edges/$edge/ca.crt /runtime/edges/$edge/client.crt 2>&1")" 'OK$'
done
check_ping_linux 'branch1 MPLS/private underlay independently reaches hub' branch1 172.20.113.5
check_ping_linux 'branch1 internet underlay independently reaches hub' branch1 192.0.2.116
check_ping_linux 'branch2 MPLS/private underlay independently reaches hub' branch2 172.20.113.5
check_ping_linux 'branch2 internet underlay independently reaches hub' branch2 192.0.2.116

if [[ "$BREAK_IT" == "--break-it" ]]; then
  state="$(node controller 'curl -ks https://10.113.40.10:8443/v1/status')"
  check_contains 'revoked branch1 loses controller control state while underlays stay healthy' "$state" '"branch1"[^}]*"control": "down"'
  check_not_contains 'revoked branch1 overlay interfaces are withdrawn' "$(node branch1 'wg show interfaces || true')" 'wg-mpls-hub|wg-inet-hub'
  summary
fi

state="$(node controller 'curl -ks https://10.113.40.10:8443/v1/status')"
check_contains 'controller desired policy is acknowledged by branch1' "$state" '"branch1"[^}]*"applied_version": "v[12]"'
check_contains 'controller desired policy is acknowledged by branch2' "$state" '"branch2"[^}]*"applied_version": "v[12]"'
check_contains 'branch1 WireGuard MPLS tunnel has a peer' "$(node branch1 'wg show wg-mpls-hub peers')" '[A-Za-z0-9+/]{40,}'
check_contains 'branch1 WireGuard internet tunnel has a peer' "$(node branch1 'wg show wg-inet-hub peers')" '[A-Za-z0-9+/]{40,}'
check_ping_linux 'CORP branch1 reaches hub private application through overlay' corp1 10.113.30.10
check_ping_linux 'CORP branch2 reaches hub private application through overlay' corp2 10.113.30.10
check_ping_linux 'CORP routes exchange through hub' corp1 10.113.20.10
check_no_ping_linux 'GUEST cannot reach private hub service' guest1 10.113.30.10
check_contains 'GUEST uses selective local internet breakout to SaaS' "$(node guest1 'curl -fsS --max-time 3 http://10.113.50.10:8080 | head -1')" '<!DOCTYPE HTML>'
check_contains 'critical private application is initially MPLS-selected' "$(node branch1 'ip route show table 100 10.113.30.0/24')" 'wg-mpls-hub'
check_contains 'bulk/SaaS has internet breakout route' "$(node branch1 'ip route get 10.113.50.10')" 'eth3'

# Live policy audit and rollback (the controller reconciles v2 then v1).
node controller 'python3 /controllerctl.py publish v2'
sleep 3
check_contains 'edges apply centrally published v2 policy' "$(node controller 'curl -ks https://10.113.40.10:8443/v1/status')" '"applied_version": "v2"'
node controller 'python3 /controllerctl.py rollback v1'
sleep 3
check_contains 'rollback restores v1 policy and service' "$(node controller 'curl -ks https://10.113.40.10:8443/v1/status')" '"applied_version": "v1"'
check_ping_linux 'private application remains reachable after rollback' corp1 10.113.30.10
summary
