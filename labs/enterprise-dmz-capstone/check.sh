#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-dmz-capstone"

check_contains "fw-outside has DNAT" "$(node fw-outside 'nft list ruleset')" "dnat to 172\\.16\\.0\\.2"
check_contains "fw-outside has masquerade" "$(node fw-outside 'nft list ruleset')" "masquerade"
check_contains "fw-inside allows db flow" "$(node fw-inside 'nft list ruleset')" "10\\.0\\.0\\.2.*3306|3306.*10\\.0\\.0\\.2"

check_contains "internet-client reaches published web" \
  "$(node internet-client 'curl -sS --max-time 4 http://203.0.114.2 || true')" \
  "Hello from web-server"

check_contains "internet-client reaches published mail" \
  "$(node internet-client 'timeout 5 nc 203.0.114.2 25')" \
  "220 mail-server"

check_ping_linux "workstation reaches internet" workstation 203.0.113.1

check_contains "web-server reaches db" \
  "$(node web-server 'echo | nc -w2 10.0.0.2 3306')" \
  "Welcome to db-server"

check_contains "outside tcp 3306 blocked" \
  "$(node internet-client 'nc -zw2 203.0.114.2 3306 >/dev/null 2>&1; echo $?')" \
  "^1$"

check_contains "mail-server db pivot blocked" \
  "$(node mail-server 'nc -zw2 10.0.0.2 3306 >/dev/null 2>&1; echo $?')" \
  "^1$"

summary
