#!/usr/bin/env bash
# Asserts the SOLVED end state — run after the management ACL is applied.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "management-access-control"

if docker exec "clab-${TOPO_NAME}-admin1" nc -zw2 192.168.99.1 22 &>/dev/null
then pass "admin1→device1 SSH permitted"
else fail "admin1→device1 SSH permitted" "TCP/22 not reachable from admin1"; fi

if ! docker exec "clab-${TOPO_NAME}-guest1" nc -zw2 192.168.50.1 22 &>/dev/null
then pass "guest1→device1 SSH denied"
else fail "guest1→device1 SSH denied" "TCP/22 unexpectedly open from guest1"; fi

check_contains "device1 MGMT-IN chain populated" \
  "$(docker exec "clab-${TOPO_NAME}-device1" iptables -L MGMT-IN -n 2>/dev/null)" \
  "ACCEPT|DROP|REJECT"

summary
