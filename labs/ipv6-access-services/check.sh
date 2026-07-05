#!/usr/bin/env bash
# Asserts the SOLVED end state — run after completing the README tasks
# (RAs with RDNSS/DNS working at the access edge).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "ipv6-access-services"

nsh() { docker exec "clab-${TOPO_NAME}-$1" sh -c "$2" 2>/dev/null; }

check_contains "client1 has a SLAAC global address" \
  "$(nsh client1 'ip -6 addr show dev eth1')" "2001:db8:10:"
check_contains "client1 learned an IPv6 default route" \
  "$(nsh client1 'ip -6 route')" "^default"

if docker exec "clab-${TOPO_NAME}-client1" ping -6 -c3 -W2 2001:db8:10::53 &>/dev/null
then pass "client1→DNS server over IPv6"
else fail "client1→DNS server over IPv6" "ping 2001:db8:10::53 failed"; fi

check_contains "client1 resolves app6.internal.lab (AAAA)" \
  "$(nsh client1 'dig +short @2001:db8:10::53 app6.internal.lab AAAA')" ":"

summary
