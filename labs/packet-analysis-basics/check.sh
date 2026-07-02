#!/usr/bin/env bash
# Asserts the baseline the capture exercises depend on.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "packet-analysis-basics"

nsh() { docker exec "clab-${TOPO_NAME}-$1" sh -c "$2" 2>/dev/null; }

check_contains "r1 OSPF neighbor Full" "$(frr r1 'show ip ospf neighbor')" "Full"
check_ping_linux "client→r2 far side" client 10.2.0.1
check_contains "services listening on 8080" "$(nsh services 'ss -ltn')" ":8080"
check_contains "client HTTP request to services succeeds" \
  "$(nsh client 'printf "GET /healthz HTTP/1.0\r\n\r\n" | nc -w3 10.2.0.2 8080')" "HTTP|healthz|ok"

summary
