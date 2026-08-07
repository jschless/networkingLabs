#!/usr/bin/env bash
set -euo pipefail

container=clab-anycast-dns-dns1
[[ "$(docker inspect --format '{{.State.Running}}' "$container" 2>/dev/null)" == true ]] \
    || { echo "anycast-dns is not running; deploy it first" >&2; exit 2; }

docker exec "$container" sh /usr/local/bin/scenario-state.sh repair >/dev/null
echo "Resolver service and route-health coupling repaired."
