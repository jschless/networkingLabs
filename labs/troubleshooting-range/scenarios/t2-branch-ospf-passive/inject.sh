#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-core2 vtysh -c 'configure terminal' -c 'interface eth5' -c shutdown -c end
for _ in $(seq 1 10); do
  if ! docker exec clab-troubleshooting-range-branch-client ping -c 1 -W 1 10.250.40.10 >/dev/null 2>&1; then echo 'Ticket symptom is active.'; exit 0; fi
  sleep 1
done
echo 'ERROR: ticket symptom did not become active' >&2
exit 1
