#!/usr/bin/env bash
# Asserts the SOLVED end state of the mpls-ldp lab: OSPF underlay up,
# LDP sessions OPERATIONAL, labels bound and installed, labeled data path.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "mpls-ldp"

# OSPF underlay: far-end loopbacks routed
check_contains "r1 OSPF route to r4 loopback" "$(frr r1 'show ip route 10.0.0.4/32')" '10\.1\.12\.2, via eth1'
check_contains "r4 OSPF route to r1 loopback" "$(frr r4 'show ip route 10.0.0.1/32')" '10\.1\.34\.1, via eth1'

# LDP sessions: both transit routers hold two OPERATIONAL sessions
check_contains "r2 LDP session to r1" "$(frr r2 'show mpls ldp neighbor')" "10\.0\.0\.1 +OPERATIONAL"
check_contains "r2 LDP session to r3" "$(frr r2 'show mpls ldp neighbor')" "10\.0\.0\.3 +OPERATIONAL"
check_contains "r3 LDP session to r4" "$(frr r3 'show mpls ldp neighbor')" "10\.0\.0\.4 +OPERATIONAL"

# Label bindings: liberal retention on r2 for r4's FEC
check_contains "r2 has binding for 10.0.0.4/32" "$(frr r2 'show mpls ldp binding')" "10\.0\.0\.4/32"

# LFIB: LDP entries actually installed in the label table
check_contains "r2 LFIB has LDP entries" "$(frr r2 'show mpls table')" "LDP"

# PHP: r4 advertises implicit-null for its own loopback (default config)
check_contains "r3 sees imp-null from r4" "$(frr r3 'show mpls ldp binding')" "10\.0\.0\.4/32.*(imp-null|implicit-null)"

# Ingress label push on the LERs
check_contains "r1 pushes a label toward 10.0.0.4/32" "$(frr r1 'show ip route 10.0.0.4/32')" "label"

# Data path end to end (loopback-to-loopback rides the LSP both ways)
check_ping_linux "r1→r4 loopback-to-loopback" r1 10.0.0.4 10.0.0.1
check_ping_linux "r4→r1 loopback-to-loopback" r4 10.0.0.1 10.0.0.4

summary
