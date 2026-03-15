#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "debug-vrf-lite"

check_ping_eos "ce-a1→ce-a2 loopback" ce-a1 10.10.0.2 10.10.0.1
check_ping_eos "ce-a2→ce-a1 loopback" ce-a2 10.10.0.1 10.10.0.2
check_ping_eos "ce-b1→ce-b2 loopback" ce-b1 10.20.0.2 10.20.0.1
check_ping_eos "ce-b2→ce-b1 loopback" ce-b2 10.20.0.1 10.20.0.2
check_no_ping_eos "ce-a1 cannot reach VRF-BLUE" ce-a1 10.20.0.2

summary
