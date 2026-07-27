#!/usr/bin/env bash
set -euo pipefail
P="clab-ot-zone-conduit"
docker exec "$P-idmz-fw" sh -c '
  handle=$(nft -a list chain inet ot_conduits forward | awk "/OT-BREAK-900/{print \$NF}")
  test -z "$handle" || nft delete rule inet ot_conduits forward handle "$handle"
'
echo "Removed only OT-BREAK-900; the intended conduit policy remains loaded."
