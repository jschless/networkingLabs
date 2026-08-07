#!/usr/bin/env bash
# Inject the endpoint-locality scenario without disclosing its mutation.
set -euo pipefail

node=clab-k8s-fabric-k3s1
[[ "$(docker inspect --format '{{.State.Running}}' "$node" 2>/dev/null)" == true ]] \
  || { echo "ERROR: k8s-fabric is not deployed" >&2; exit 1; }

docker exec "$node" sh /scenario-state.sh break >/dev/null
echo "Fault injected. Start at the client, then follow the service, endpoints, advertisements, and ToR route."
