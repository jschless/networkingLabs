#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "soc-zeek-analysis"

node attacker "/opt/soc-lab/run-attack-sequence.sh" >/dev/null || true
node sensor "/usr/local/bin/generate-soc-artifacts" >/dev/null
check_contains "Zeek conn log has web HVT" "$(node sensor 'cat /var/log/zeek/conn.log')" "172.16.10.10"
check_contains "Zeek http log has file URI" "$(node sensor 'cat /var/log/zeek/http.log')" "/downloads/readme.txt"
check_contains "Zeek notice has scan" "$(node sensor 'cat /var/log/zeek/notice.log')" "Port_Scan"

summary
