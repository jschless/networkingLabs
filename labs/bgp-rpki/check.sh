#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "bgp-rpki"

check_contains "edge BGP Established isp1" "$(eos edge 'show bgp summary')" "Estab"
check_contains "RPKI cache connected" "$(eos edge 'show rpki provider-table')" "connected"
# isp1's prefix should be VALID; hijacker's should be INVALID
check_contains "10.100.0.0/24 valid" "$(eos edge 'show bgp ipv4 unicast 10.100.0.0/24')" "valid"

summary
