#!/usr/bin/env bash
set -euo pipefail

WORKSPACE=/workspace
STAGE="$WORKSPACE/.precheck-$$"

cleanup() {
  rm -rf "$STAGE"
}
trap cleanup EXIT INT TERM

python3 "$WORKSPACE/render_from_netbox.py" --output "$STAGE"
ansible-playbook -i "$WORKSPACE/inventory.yml" "$WORKSPACE/deploy.yml" \
  --check --diff -e "candidate_dir=$STAGE"
