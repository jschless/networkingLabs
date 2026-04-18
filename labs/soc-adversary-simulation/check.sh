#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "soc-adversary-simulation"

node attacker "/opt/soc-lab/run-attack-sequence.sh" >/dev/null || true
node sensor "/usr/local/bin/generate-soc-artifacts" >/dev/null
check_contains "T1046 detected" "$(node sensor 'cat /var/log/soc/detection-matrix.json')" "T1046"
check_contains "T1110 detected" "$(node sensor 'cat /var/log/soc/detection-matrix.json')" "T1110"
check_contains "Detection matrix parseable" "$(node sensor 'jq -r .[0].status /var/log/soc/detection-matrix.json')" "detected"

summary
