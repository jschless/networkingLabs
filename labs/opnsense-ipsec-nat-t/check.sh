#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "opnsense-ipsec-nat-t"
check_ping_linux "HQ host reaches branch host through IPsec" hq-host 10.20.1.10
check_ping_linux "branch host reaches HQ host through IPsec" branch-host 10.10.1.10
check_contains "NAT CPE owns the public mapping" "$(node nat-cpe 'iptables -t nat -S')" "MASQUERADE"
check_contains "NAT CPE forwards IKE/NAT-T" "$(node nat-cpe 'iptables -t nat -S')" "dport 4500"
summary
