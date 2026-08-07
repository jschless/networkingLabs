#!/usr/bin/env bash
# Inject a reverse-path routing fault without revealing it to the learner.
set -euo pipefail

EDGE="clab-urpf-antispoofing-edge"

docker exec "$EDGE" su - admin -c \
  '/bin/vbash /opt/inject-fault.sh' >/dev/null

fault_route="$(docker exec "$EDGE" ip -4 route show 10.0.0.10/32)"
if ! printf '%s\n' "$fault_route" | grep -qE \
    '^10\.0\.0\.10 (nhid [0-9]+ )?via 10\.10\.2\.2 dev eth2'; then
  echo "Fault injection failed: expected reverse-path change is not installed." >&2
  exit 1
fi

echo "Fault injected. Diagnose from the FIB, packet evidence, and uRPF counters."
