#!/usr/bin/env bash
set -euo pipefail

LAB=network-automation-netbox
AUTOMATION="clab-$LAB-automation"

docker exec "$AUTOMATION" python3 /workspace/wait_for_netbox.py --timeout 360 >/dev/null
docker exec "$AUTOMATION" python3 /workspace/fault_assignment.py repair
docker exec "$AUTOMATION" python3 /workspace/render_from_netbox.py
