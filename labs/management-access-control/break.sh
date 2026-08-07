#!/usr/bin/env bash
# Inject the Task 5 first-match fault. Re-running keeps the same fault state.
set -euo pipefail

DEVICE="clab-management-access-control-device1"

docker exec "$DEVICE" Cli -p 15 -c $'enable\nconfigure\nip access-list MGMT-PLANE\n5 deny tcp any any\nend' >/dev/null

echo "Fault injected. Diagnose from the client symptoms and device evidence."
