#!/usr/bin/env bash
set -euo pipefail

P="clab-network-gitops-change-pipeline-automation"
WORK="/workspace/lab-repo"

docker exec -w "$WORK" "$P" python3 -m pipeline.cli rollback
docker exec -w "$WORK" "$P" git revert --no-edit HEAD
docker exec -w "$WORK" "$P" python3 -m pipeline.cli run
echo "Repair complete: applied device rolled back, stale inventory reverted, v2 verified."
