#!/usr/bin/env bash
# Asserts the reference end state (this lab deploys pre-built).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-wireless-architecture"

nsh() { docker exec "clab-${TOPO_NAME}-$1" sh -c "$2" 2>/dev/null; }

check_contains "ap1 has management subinterface eth1.99" \
  "$(nsh ap1 'ip addr show')" "eth1\.99"
check_contains "ap1 reaches the WLC on 8080" \
  "$(nsh ap1 'curl -s -m 5 http://192.168.99.10:8080')" "."
# Ping THROUGH the gateway SVIs to the WLC rather than pinging the SVI
# addresses themselves: routed transit proves the gateways work, and cEOS
# containers do not reliably answer traffic addressed to their own
# dataplane interfaces.
check_ping_linux "corp-sta routed via corp gateway to WLC"   corp-sta  192.168.99.10
check_ping_linux "guest-sta routed via guest gateway to WLC" guest-sta 192.168.99.10

summary
