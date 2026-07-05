#!/usr/bin/env bash
# Asserts the SOLVED end state — run after completing the README tasks.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "acl-basics"

tcp_open()   { docker exec "clab-${TOPO_NAME}-$1" nc -zw2 "$2" "$3" &>/dev/null; }

check_ping_linux "client→router mgmt IP" client 192.168.10.1

if tcp_open client 192.168.10.1 8080; then pass "client→8080 permitted"
else fail "client→8080 permitted" "expected TCP/8080 open for client"; fi

if ! tcp_open client 192.168.10.1 2222; then pass "client→2222 denied"
else fail "client→2222 denied" "TCP/2222 unexpectedly open for client"; fi

if ! tcp_open attacker 192.168.20.1 8080; then pass "attacker→8080 denied"
else fail "attacker→8080 denied" "TCP/8080 unexpectedly open for attacker"; fi

check_contains "router MGMT-ACL chain exists" \
  "$(docker exec "clab-${TOPO_NAME}-router" iptables-legacy -L INPUT -n 2>/dev/null)" \
  "MGMT-ACL"

summary
