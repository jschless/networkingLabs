#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "soc-dmz-foundation"

check_ping_linux "attacker->router-fw" attacker 10.10.10.1
check_ping_linux "attacker->dmz-web" attacker 172.16.10.10
check_ping_linux "attacker->dmz-api" attacker 172.16.20.10
check_contains "dmz-web HTTP" "$(node attacker 'curl -fsS http://172.16.10.10/')" "dmz-web online"
check_contains "dmz-api HTTP" "$(node attacker 'curl -fsS http://172.16.20.10:8080/')" "dmz-api online"
check_contains "sensor artifact generator" "$(node sensor 'test -x /usr/local/bin/generate-soc-artifacts && echo ok')" "ok"

summary
