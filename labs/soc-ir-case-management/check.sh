#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "soc-ir-case-management"

node sensor "/usr/local/bin/generate-soc-artifacts" >/dev/null
check_contains "Case artifact present" "$(node case-mgmt 'cat /var/lib/thehive/case.json')" "SOC Lab DMZ Intrusion"
check_contains "Case has observables" "$(node case-mgmt 'jq -r .observables[] /var/lib/thehive/case.json')" "10.10.10.10"
check_contains "Incident timeline present" "$(node sensor 'cat /var/log/soc/incident-timeline.md')" "attacker browsed dmz-web"

summary
