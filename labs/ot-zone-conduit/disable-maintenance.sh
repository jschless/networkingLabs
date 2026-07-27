#!/usr/bin/env bash
set -euo pipefail
P="clab-ot-zone-conduit"
for node in plc1 plc2; do
  docker exec "$P-$node" sh -c '
    if test -f /run/ot/expiry.pid; then kill "$(cat /run/ot/expiry.pid)" 2>/dev/null || true; fi
    rm -f /run/ot/maintenance.enabled
    handle=$(nft -a list chain inet plc_guard input | awk "/OT-RULE-450/{print \$NF}")
    test -z "$handle" || nft delete rule inet plc_guard input handle "$handle"
  '
done
echo "Synthetic maintenance window disabled."
