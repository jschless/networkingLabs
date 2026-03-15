#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "ipv6-bgp"

check_contains "r1 BGP Established" "$(eos r1 'show bgp summary')" "Estab"
check_contains "r2 BGP Established" "$(eos r2 'show bgp summary')" "Estab"
check_contains "r3 BGP Established" "$(eos r3 'show bgp summary')" "Estab"
check_ping_eos "r1→r4 IPv4" r1 10.0.0.4 10.0.0.1
check_contains "r1→r4 IPv6 ping" "$(eos r1 'ping ipv6 2001:db8::4 repeat 3 timeout 2')" "0% packet loss"

summary
