#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "ipv6-ospf3"

check_contains "r1 OSPFv3 Full" "$(eos r1 'show ipv6 ospf neighbor')" "Full"
check_contains "r2 OSPFv3 Full" "$(eos r2 'show ipv6 ospf neighbor')" "Full"
check_contains "r3 OSPFv3 Full" "$(eos r3 'show ipv6 ospf neighbor')" "Full"
# Ping r4's IPv6 loopback from r1
check_contains "r1→r4 IPv6 ping" "$(eos r1 'ping ipv6 2001:db8::4 repeat 3 timeout 2')" "0% packet loss"
check_contains "r4→r1 IPv6 ping" "$(eos r4 'ping ipv6 2001:db8::1 repeat 3 timeout 2')" "0% packet loss"

summary
