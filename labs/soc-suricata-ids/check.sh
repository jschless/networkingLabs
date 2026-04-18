#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "soc-suricata-ids"

node attacker "/opt/soc-lab/run-attack-sequence.sh" >/dev/null || true
node sensor "/usr/local/bin/generate-soc-artifacts" >/dev/null
check_contains "Suricata eve alert present" "$(node sensor 'jq -r select\(.event_type==\"alert\"\).alert.signature /var/log/suricata/eve.json')" "SSH brute force"
check_contains "Suricata web rule present" "$(node sensor 'cat /var/log/suricata/eve.json')" "SQLi"
check_contains "Suricata JSON parseable" "$(node sensor 'jq -s length /var/log/suricata/eve.json')" "2"

summary
