#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "wireless-auth-control-operations"

check_contains "FreeRADIUS is running" "$(node radius 'pgrep -a freeradius')" "freeradius"
check_contains "both wired EAP authenticators are running" "$(node authenticator 'pgrep -xc hostapd')" "2"
check_contains "control inventory labels its fidelity" "$(node authenticator 'curl -fsS http://192.168.99.1:8080/')" "wired EAPOL/RADIUS policy only"
check_contains "corporate EAP-TLS completes server validation" "$(node corp-client 'cat /var/log/wpa-corp.log')" "CTRL-EVENT-EAP-SUCCESS"
check_contains "quarantine EAP-TLS completes authorization" "$(node quarantine-client 'cat /var/log/wpa-quarantine.log')" "CTRL-EVENT-EAP-SUCCESS"
check_contains "RADIUS accepts corporate identity with VLAN 110" "$(node radius 'cat /var/log/freeradius/debug.log')" "Tunnel-Private-Group-Id.*110"
check_contains "RADIUS accepts quarantine identity with VLAN 130" "$(node radius 'cat /var/log/freeradius/debug.log')" "Tunnel-Private-Group-Id.*130"
check_contains "corporate port is projected to VLAN 110" "$(node authenticator 'bridge vlan show dev eth1')" "110 PVID Egress Untagged"
check_contains "quarantine port is projected to VLAN 130" "$(node authenticator 'bridge vlan show dev eth3')" "130 PVID Egress Untagged"
check_ping_linux "corporate reaches approved service" corp-client 10.110.0.1
check_no_ping_linux "corporate cannot reach guest service" corp-client 10.120.0.1
check_ping_linux "guest reaches guest service" guest-client 10.120.0.1
check_no_ping_linux "guest cannot reach corporate service" guest-client 10.110.0.1
check_ping_linux "quarantine reaches remediation service" quarantine-client 10.130.0.1
check_no_ping_linux "quarantine cannot reach corporate service" quarantine-client 10.110.0.1
check_contains "corporate validation pins CA and name" "$(node corp-client 'cat /etc/wpa_supplicant/corp.conf')" "domain_suffix_match=\"radius.lab\""
check_not_contains "no virtual radio module was loaded by fallback" "$(lsmod)" "mac80211_hwsim"
summary
