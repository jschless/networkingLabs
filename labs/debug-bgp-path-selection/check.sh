#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "debug-bgp-path-selection"

check_contains "ce1 BGP Established" "$(eos ce1 'show bgp summary')" "Estab"
check_contains "isp1 BGP Established" "$(eos isp1 'show bgp summary')" "Estab"
check_contains "ce2 BGP Established" "$(eos ce2 'show bgp summary')" "Estab"
check_ping_eos "ce1→ce2 loopback" ce1 10.0.0.4 10.0.0.1
check_ping_eos "ce2→ce1 loopback" ce2 10.0.0.1 10.0.0.4

summary
