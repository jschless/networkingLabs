#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "dmvpn-phase3-ipsec-capstone"

# single-token match arguments only: vyos_op wraps its command in nested
# single quotes, so a quoted multi-word match pattern breaks out of the
# vbash -ic quoting and "match" runs as a host command.
check_contains "hub imports DMVPN CA" \
  "$(vyos_op hub 'show configuration commands | match DMVPN-CA')" \
  "pki ca DMVPN-CA"
check_contains "spoke1 imports local cert" \
  "$(vyos_op spoke1 'show configuration commands | match spoke1-cert')" \
  "pki certificate spoke1-cert"
check_contains "hub uses x509 auth" \
  "$(vyos_op hub 'show configuration commands | match x509')" \
  "authentication mode .x509."
check_contains "spoke1 uses x509 auth" \
  "$(vyos_op spoke1 'show configuration commands | match x509')" \
  "authentication mode .x509."
check_contains "hub has NHRP entries" \
  "$(vyos_frr hub 'show ip nhrp')" \
  "172\.16\.0\.(11|12|13)"
check_contains "hub sees spoke1 OSPF Full" \
  "$(vyos_frr hub 'show ip ospf neighbor')" \
  "Full/.+172\.16\.0\.11"
check_contains "hub sees spoke2 OSPF Full" \
  "$(vyos_frr hub 'show ip ospf neighbor')" \
  "Full/.+172\.16\.0\.12"
check_contains "hub sees spoke3 OSPF Full" \
  "$(vyos_frr hub 'show ip ospf neighbor')" \
  "Full/.+172\.16\.0\.13"
check_contains "hub has IKE peers" \
  "$(vyos_op hub 'show vpn ike sa')" \
  "10\.0\.0\.(11|12|13)|spoke1\.dmvpn\.lab|spoke2\.dmvpn\.lab|spoke3\.dmvpn\.lab"
check_contains "spoke1 has IPsec SA output" \
  "$(vyos_op spoke1 'show vpn ipsec sa')" \
  "10\.0\.0\.(1|12|13)|ESP|INSTALLED|up"
check_contains "spoke1 learns summary" \
  "$(vyos_op spoke1 'show ip route 192.168.0.0/16')" \
  "172\.16\.0\.1|via tun0"
check_ping_vyos "hub→spoke1 LAN" hub 192.168.1.1
check_ping_vyos "spoke1→spoke2 LAN" spoke1 192.168.2.1
check_ping_vyos "spoke2→spoke3 LAN" spoke2 192.168.3.1
# Phase 3 shortcuts install as NHRP host routes (/32), not the /24, so ask
# the RIB for NHRP-sourced routes after the spoke1→spoke2 ping above.
check_contains "spoke1 installs shortcut route" \
  "$(vyos_frr spoke1 'show ip route nhrp')" \
  "192\.168\.2\..+(172\.16\.0\.12|tun0)"

summary
