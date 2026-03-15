#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "isis-multiarea"

check_contains "r1 IS-IS Up" "$(eos r1 'show isis neighbors')" "Up"
check_contains "r2 IS-IS Up" "$(eos r2 'show isis neighbors')" "Up"
check_contains "r3 IS-IS Up" "$(eos r3 'show isis neighbors')" "Up"
check_ping_eos "r1→r5 loopback" r1 10.0.0.5 10.0.0.1
check_ping_eos "r5→r1 loopback" r5 10.0.0.1 10.0.0.5

summary
