#!/usr/bin/env bash
# Asserts the traffic baseline the QoS tasks depend on. The tc policy itself
# is applied and removed during the tasks, so it is not asserted here.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "qos-enterprise"

check_ping_linux "client-voice→server" client-voice 10.2.0.2
check_ping_linux "client-video→server" client-video 10.2.0.2
check_ping_linux "client-data→server"  client-data  10.2.0.2

check_contains "router forwards for all three classes" \
  "$(docker exec "clab-${TOPO_NAME}-router" ip -br addr 2>/dev/null)" "10\.2\.0\.1"

summary
