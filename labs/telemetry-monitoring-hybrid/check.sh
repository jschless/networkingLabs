#!/usr/bin/env bash
# Asserts the SOLVED end state — run after the EOS management tasks.
# This lab has two topology variants (full/lite); detect whichever is deployed.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"

if docker ps --format '{{.Names}}' | grep -q '^clab-telemetry-monitoring-full-'; then
  TOPO_NAME="telemetry-monitoring-full"
elif docker ps --format '{{.Names}}' | grep -q '^clab-telemetry-monitoring-lite-'; then
  TOPO_NAME="telemetry-monitoring-lite"
else
  echo "ERROR: no telemetry-monitoring containers running. Deploy full or lite first."
  exit 2
fi
LAB="telemetry-monitoring-hybrid"
echo "=== Checking lab: $LAB (topology: $TOPO_NAME) ==="

check_ping_linux "client→server across the routed core" client 10.20.20.11
check_contains "campus1 gNMI management API configured" \
  "$(eos campus1 'show running-config section management api gnmi')" "gnmi"
# core1 is cEOS only in the full variant; in lite it is an FRR node.
if [[ "$TOPO_NAME" == "telemetry-monitoring-full" ]]; then
  check_contains "core1 gNMI management API configured" \
    "$(eos core1 'show running-config section management api gnmi')" "gnmi"
else
  check_contains "core1 (FRR) BGP/IGP daemon up" \
    "$(frr core1 'show version')" "FRRouting"
fi

summary
