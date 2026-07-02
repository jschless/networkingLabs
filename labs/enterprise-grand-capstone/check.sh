#!/usr/bin/env bash
# Asserts the deployed integration end state (README Part A + Verification).
# Run after `./gcap.sh deploy` has settled (~60s for dc1 provisioning).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-grand-capstone"

nsh() { docker exec "clab-${TOPO_NAME}-$1" sh -c "$2" 2>/dev/null; }

check_contains "A1: corp-pc 802.1X authenticated (EAP-SUCCESS)" \
  "$(nsh corp-pc 'grep EAP-SUCCESS /var/log/wpa.log')" "EAP-SUCCESS"
check_contains "A2: corp-pc holds a relayed Kea lease (VLAN 10)" \
  "$(nsh corp-pc 'ip -br addr show eth1')" "10\.10\.10\."
check_contains "A2: DDNS PTR for the corp lease resolves" \
  "$(nsh corp-pc 'host 10.10.10.100 10.100.1.40')" "lab\.corp"
check_contains "A3: corp-pc resolves dc1.lab.corp" \
  "$(nsh corp-pc 'nslookup dc1.lab.corp 10.100.1.40')" "10\.100\.1\.10"
check_contains "A3: kinit bob against the real AD" \
  "$(nsh corp-pc 'echo P@ssw0rd1 | kinit bob && klist')" "krbtgt/LAB\.CORP"

check_no_ping_linux "A4: guest-pc blocked from services" guest-pc 10.100.1.10
check_ping_linux    "A4: guest-pc still reaches internet" guest-pc 1.1.1.1
check_ping_linux    "A4: corp-pc reaches services"        corp-pc  10.100.1.10

check_contains "F4 baseline: single VRRP master per VLAN on cc1/cc2" \
  "$(eos cc1 'show vrrp brief'; eos cc2 'show vrrp brief')" "aster"

summary
