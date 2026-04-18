#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "soc-arkime-pcap"

check_contains "Arkime session index has web session" "$(node arkime 'cat /var/lib/arkime/sessions.json')" "172.16.10.10"
check_contains "Arkime session index has api session" "$(node arkime 'cat /var/lib/arkime/sessions.json')" "172.16.20.10"
check_contains "Arkime JSON parseable" "$(node arkime 'jq -r .[0].protocol /var/lib/arkime/sessions.json')" "http"
check_contains "Sensor pcap placeholder present" "$(node sensor 'ls /pcap/soc-lab-demo.pcap')" "soc-lab-demo.pcap"

summary
