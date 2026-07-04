#!/usr/bin/env bash
# Asserts the SOLVED end state — run after completing the README tasks
# (PAT for inside, static NAT for the published service, guest isolation).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-edge-nat-firewall"

nsh() { docker exec "clab-${TOPO_NAME}-$1" sh -c "$2" 2>/dev/null; }

check_contains "internet-client reaches published web service (static NAT)" \
  "$(nsh internet-client 'curl -sI -m 5 http://203.0.114.2')" "HTTP/"
# Target the internet HOST (203.0.113.2), not the ISP cEOS interface:
# reaching it proves PAT + transit through the ISP, and cEOS containers do
# not reliably answer traffic addressed to themselves.
check_ping_linux "workstation→internet host (PAT out)"  workstation  203.0.113.2
check_ping_linux "guest-laptop→internet host (PAT out)" guest-laptop 203.0.113.2
check_no_ping_linux "guest blocked from db-server"    guest-laptop 10.0.0.2
check_no_ping_linux "guest blocked from workstation"  guest-laptop 10.0.0.6

summary
