#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "soc-yara-file-pipeline"

node attacker "curl -fsS http://172.16.10.10/downloads/readme.txt >/dev/null" >/dev/null || true
node sensor "/usr/local/bin/generate-soc-artifacts" >/dev/null
check_contains "Extracted file present" "$(node sensor 'cat /extract_files/readme.txt')" "SOC_LAB_TEST_FILE"
check_contains "YARA hit present" "$(node sensor 'cat /var/log/yara/hits.json')" "SOC_LAB_Test_File"
check_contains "YARA JSON parseable" "$(node sensor 'jq -r .rule /var/log/yara/hits.json')" "SOC_LAB_Test_File"

summary
