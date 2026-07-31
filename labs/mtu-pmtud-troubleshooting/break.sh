#!/usr/bin/env bash
# Inject a one-sided regression without naming its mechanism.
set -euo pipefail

EDGE_B="clab-mtu-pmtud-troubleshooting-edge-b"

docker exec "$EDGE_B" su - admin -c \
  '/bin/vbash /opt/inject-fault.sh' >/dev/null

link_state="$(docker exec "$EDGE_B" ip -o link show tun0)"
if ! printf '%s\n' "$link_state" | grep -qE '[[:space:]]mtu 1300[[:space:]]'; then
  echo "Fault injection failed: expected operational postcondition was not reached." >&2
  exit 1
fi

echo "Fault injected. Compare the safe-payload result in both directions and diagnose the regression."
