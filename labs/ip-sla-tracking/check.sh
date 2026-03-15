#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "ip-sla-tracking"

check_contains "SLA probe Up" "$(eos router 'show ip sla statistics')" "Up"
check_contains "primary default route active" "$(eos router 'show ip route 0.0.0.0/0')" "10\.0\.1\.2"
check_ping_eos "router→isp1" router 10.99.0.1

summary
