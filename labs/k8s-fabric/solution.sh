#!/usr/bin/env bash
# Restore the validated service policy and endpoint distribution.
set -euo pipefail

node=clab-k8s-fabric-k3s1
[[ "$(docker inspect --format '{{.State.Running}}' "$node" 2>/dev/null)" == true ]] \
  || { echo "ERROR: k8s-fabric is not deployed" >&2; exit 1; }

docker exec "$node" sh /scenario-state.sh repair >/dev/null
echo "Repair applied. Verify endpoint placement, the ToR FIB, and client HTTP."
