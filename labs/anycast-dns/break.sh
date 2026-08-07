#!/usr/bin/env bash
set -euo pipefail

container=clab-anycast-dns-dns1
[[ "$(docker inspect --format '{{.State.Running}}' "$container" 2>/dev/null)" == true ]] \
    || { echo "anycast-dns is not running; deploy it first" >&2; exit 2; }

docker exec "$container" sh /usr/local/bin/scenario-state.sh break >/dev/null
echo "Fault injected. Diagnose the site-1 DNS failure without inspecting the injector."
