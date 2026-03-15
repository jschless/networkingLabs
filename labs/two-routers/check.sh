#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "two-routers"

out=$(eos r1 "show ip ospf neighbor")
check_contains "r1 OSPF neighbor Full" "$out" "Full"
check_ping_eos "r1→r2" r1 10.0.0.2

summary
