#!/usr/bin/env bash
# Asserts the SOLVED end state — run after the poller has been run once.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "suzieq-network-observability"

nsh() { docker exec "clab-${TOPO_NAME}-$1" sh -c "$2" 2>/dev/null; }

check_contains "r2 OSPF neighbors Full (hub sees r1+r3)" \
  "$(eos r2 'show ip ospf neighbor')" "Full"
check_ping_eos "r1→r3 loopback" r1 10.0.0.3 10.0.0.1
check_contains "suzieq container has sq-poller" \
  "$(nsh suzieq 'command -v sq-poller')" "sq-poller"
check_contains "poller output present in /workspace/parquet-out" \
  "$(nsh suzieq 'ls /workspace/parquet-out')" "."

summary
