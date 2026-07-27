#!/usr/bin/env bash
set -euo pipefail
P="clab-ot-zone-conduit"
docker exec "$P-idmz-fw" sh -c '
  handle=$(nft -a list chain inet ot_conduits forward | awk "/OT-BREAK-900/{print \$NF}")
  test -z "$handle" || nft delete rule inet ot_conduits forward handle "$handle"
  nft insert rule inet ot_conduits forward iifname "eth4" oifname "br-idmz" ip daddr 10.110.20.20 tcp sport 502 counter drop comment "\"OT-BREAK-900 historian return-path drop\""
'
echo "Break-It injected: historian Modbus return traffic is dropped at the IDMZ boundary."
