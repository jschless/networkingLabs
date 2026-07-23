#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "internet-peering-ixp"

for router in enterprise peer-content peer-saas; do
  summary_output="$(frr "$router" 'show bgp ipv4 unicast summary')"
  check_contains "$router session to rs1 is established" "$summary_output" '198\.18\.70\.1[[:space:]].*N/A'
  check_contains "$router session to rs2 is established" "$summary_output" '198\.18\.70\.2[[:space:]].*N/A'
done
check_contains "enterprise-content bilateral is established" "$(frr enterprise 'show bgp ipv4 unicast summary')" '198\.18\.70\.12[[:space:]].*N/A'
check_contains "route server preserves the content next hop" "$(frr enterprise 'show bgp ipv4 unicast 198.51.100.0/24')" '198\.18\.70\.12'
check_not_contains "route server AS is not in content forwarding path" "$(frr enterprise 'show bgp ipv4 unicast 198.51.100.0/24')" ' 65010 65002'
check_contains "only content registered prefix is accepted" "$(frr enterprise 'show bgp ipv4 unicast 198.51.100.0/24')" '65002'
check_not_contains "unregistered content prefix is rejected" "$(frr enterprise 'show bgp ipv4 unicast 198.51.101.0/24')" '65002'
check_not_contains "enterprise does not transit peer routes to transit" "$(frr transit 'show bgp ipv4 unicast 198.51.100.0/24')" '65002'
check_contains "valid content route is accepted" "$(frr enterprise 'show bgp ipv4 unicast 198.51.100.0/24')" 'valid'
check_contains "not-found policy retains the SaaS route" "$(frr enterprise 'show bgp ipv4 unicast 192.0.2.0/24')" '65003'
check_contains "RPKI RTR is connected" "$(frr enterprise 'show rpki cache-connection')" 'connected'
check_contains "invalid transit origin reached the RPKI policy" "$(frr enterprise 'show bgp ipv4 unicast neighbors 192.0.2.6 received-routes')" '198\.51\.100\.0/24'
check_not_contains "invalid transit origin is not selected" "$(frr enterprise 'show bgp ipv4 unicast 198.51.100.0/24')" '192\.0\.2\.6'
check_contains "maximum-prefix protection is warning-only" "$(frr rs1 'show running-config')" 'maximum-prefix 5 80 warning-only'
check_ping_linux "enterprise reaches content service prefix" enterprise 198.51.100.10
if [[ "${1:-}" == "--break-it" ]]; then
  check_contains "Break-It keeps SaaS session established" "$(frr enterprise 'show bgp ipv4 unicast summary')" '198\.18\.70\.1[[:space:]].*[[:space:]][0-9]+[[:space:]][0-9]+[[:space:]]N/A'
  check_not_contains "stale IRR rejects new SaaS prefix" "$(frr enterprise 'show bgp ipv4 unicast 192.0.3.0/24')" '65003'
fi
if [[ "${1:-}" == "--rtbh" ]]; then
  check_contains "RTBH route is tagged with the IXP community" "$(frr enterprise 'show bgp ipv4 unicast 198.51.100.66/32')" '65010:666'
  check_no_ping_linux "RTBH drops only the selected host route" enterprise 198.51.100.66
  check_ping_linux "RTBH leaves the content service reachable" enterprise 198.51.100.10
fi
summary
