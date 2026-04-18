#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "soc-kibana-hvt-dashboard"

check_contains "Dashboard export present" "$(node siem 'cat /var/lib/soc-siem/hvt-dashboard.ndjson')" "SOC DMZ HVT Monitoring"
check_contains "Suricata severity panel present" "$(node siem 'cat /var/lib/soc-siem/hvt-dashboard.ndjson')" "Suricata alert severity"
check_contains "Zeek top sources panel present" "$(node siem 'cat /var/lib/soc-siem/hvt-dashboard.ndjson')" "Zeek top source IPs"
check_contains "YARA panel present" "$(node siem 'cat /var/lib/soc-siem/hvt-dashboard.ndjson')" "YARA file hits"

summary
