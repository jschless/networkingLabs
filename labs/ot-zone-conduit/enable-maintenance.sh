#!/usr/bin/env bash
set -euo pipefail
P="clab-ot-zone-conduit"
DURATION="${1:-60}"
[[ "$DURATION" =~ ^[0-9]+$ ]] && (( DURATION >= 5 && DURATION <= 300 )) || {
  echo "duration must be 5-300 seconds" >&2
  exit 2
}

for node in plc1 plc2; do
  docker exec "$P-$node" sh -c '
    if test -f /run/ot/expiry.pid; then kill "$(cat /run/ot/expiry.pid)" 2>/dev/null || true; fi
    handle=$(nft -a list chain inet plc_guard input | awk "/OT-RULE-450/{print \$NF}")
    test -z "$handle" || nft delete rule inet plc_guard input handle "$handle"
    nft insert rule inet plc_guard input ip saddr 10.110.40.99 tcp dport 502 counter drop comment "\"OT-RULE-450 maintenance source guard\""
    touch /run/ot/maintenance.enabled
  '
  docker exec -d -e DURATION="$DURATION" "$P-$node" \
    bash /opt/ot/expire-maintenance.sh
done
echo "Synthetic maintenance window enabled for ${DURATION}s; attacker-test remains denied."
