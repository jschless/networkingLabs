#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "soc-elk-ingest"

check_contains "SIEM has zeek index" "$(node siem 'cat /var/lib/soc-siem/indexes.json')" "zeek-conn"
check_contains "SIEM has suricata index" "$(node siem 'cat /var/lib/soc-siem/indexes.json')" "suricata-alerts"
check_contains "SIEM has yara index" "$(node siem 'cat /var/lib/soc-siem/indexes.json')" "yara-hits"
check_contains "SIEM JSON parseable" "$(node siem 'jq -r .[0].status /var/lib/soc-siem/indexes.json')" "green"

summary
