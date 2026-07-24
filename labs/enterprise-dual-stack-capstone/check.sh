#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-dual-stack-capstone"

check_contains 'dist1 OSPFv2 adjacency' "$(eos dist1 'show ip ospf neighbor')" '10\.108\.255\.(2|3)'
check_contains 'dist1 OSPFv3 adjacency' "$(eos dist1 'show ipv6 ospf neighbor')" '10\.108\.255\.3'
check_contains 'edge IPv4 eBGP established' "$(eos edge 'show ip bgp summary')" '198\.18\.108\.2.*Estab'
check_contains 'edge IPv6 eBGP established' "$(eos edge 'show bgp ipv6 unicast summary')" '2001:db8:ffff:108::2.*Estab'
check_contains 'approved IPv4 aggregate only' "$(eos edge 'show ip bgp')" '10\.108\.0\.0/16'
check_contains 'approved IPv6 aggregate only' "$(eos edge 'show bgp ipv6 unicast')" '2001:db8:108::/48'
check_not_contains 'no ULA reaches ISP' "$(frr isp 'show bgp ipv6 unicast')" 'fc00:'
check_contains 'A record' "$(node corp-client 'dig +short @10.108.30.10 app.corp.example A')" '10\.108\.40\.10'
check_contains 'AAAA record' "$(node corp-client 'dig +short @10.108.30.10 app.corp.example AAAA')" '2001:db8:108:40::10'
check_contains 'IPv4 reverse record' "$(node corp-client 'dig +short @10.108.30.10 -x 10.108.10.10')" 'corp-client\.corp\.example'
check_ping_linux 'corp reaches dual-stack app over IPv4' corp-client 10.108.40.10
check_ping_linux 'corp reaches dual-stack app over IPv6' corp-client 2001:db8:108:40::10
check_contains 'dual-stack HTTP works over IPv4' "$(node corp-client 'curl -4 --max-time 5 -s http://10.108.40.10:8080')" 'dual-stack'
check_contains 'dual-stack HTTP works over IPv6' "$(node corp-client 'curl -6 --max-time 5 -s http://[2001:db8:108:40::10]:8080')" 'dual-stack'
check_contains 'IPv4-only behavior remains explicit' "$(node corp-client 'dig +short @10.108.30.10 v4only.corp.example A')" '10\.108\.41\.10'
check_ping_linux 'guest reaches public IPv4' guest-client 198.18.109.10
check_no_ping_linux 'guest cannot reach internal app over IPv4' guest-client 10.108.40.10
check_no_ping_linux 'guest cannot reach internal app over IPv6' guest-client 2001:db8:108:40::10
if [[ "${1:-}" == '--break-it' ]]; then
  check_contains 'Break-It blackholes the app IPv6 return route' "$(eos dist2 'show ipv6 route 2001:db8:108:10::/64')" 'Null0'
fi
summary
