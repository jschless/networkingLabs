#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "soc-threat-intel-misp"

check_contains "MISP IOC present" "$(node misp 'cat /var/lib/misp/iocs.json')" "172.16.10.10"
check_contains "MISP Suricata export present" "$(node misp 'cat /etc/suricata/rules/misp-generated.rules')" "MISP IOC"
check_contains "IOC JSON parseable" "$(node misp 'jq -r .[0].event /var/lib/misp/iocs.json')" "SOC-LAB-DMZ-HVT"

summary
