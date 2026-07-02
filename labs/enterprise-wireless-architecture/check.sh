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
check_ping_linux "corp-sta→corp gateway"   corp-sta  10.110.0.1
check_ping_linux "guest-sta→guest gateway" guest-sta 10.120.0.1

summary
