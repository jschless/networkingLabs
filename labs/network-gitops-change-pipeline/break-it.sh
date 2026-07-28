#!/usr/bin/env bash
set -euo pipefail

P="clab-network-gitops-change-pipeline-automation"
WORK="/workspace/lab-repo"

docker exec -w "$WORK" "$P" python3 -m pipeline.cli inject-partial
if docker exec -w "$WORK" "$P" python3 -m pipeline.cli run; then
  echo "ERROR: stale leaf2 capability data unexpectedly succeeded" >&2
  exit 1
fi
docker exec -w "$WORK" "$P" python3 -m pipeline.cli history
echo "Break-It ready: leaf1 accepted v3, leaf2 rejected it, and edge1 was not attempted."
