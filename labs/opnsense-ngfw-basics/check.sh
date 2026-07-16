#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "opnsense-ngfw-basics"

check_contains "corp reaches public HTTP" "$(node corp-client 'curl -m5 -fsS http://198.51.100.10 || true')" "public internet"
check_contains "guest reaches public HTTP" "$(node guest-client 'curl -m5 -fsS http://198.51.100.10 || true')" "public internet"
check_contains "internet reaches published DMZ HTTP" "$(node internet-client 'curl -m5 -fsS http://203.0.113.2 || true')" "DMZ web"
check_no_ping_linux "guest cannot reach corp" guest-client 10.10.10.10
check_no_ping_linux "guest cannot reach DB" guest-client 10.30.30.10
check_no_ping_linux "internet cannot reach corp" internet-client 10.10.10.10
check_no_ping_linux "internet cannot reach DB" internet-client 10.30.30.10
summary
