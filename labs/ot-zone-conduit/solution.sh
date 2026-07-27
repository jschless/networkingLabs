#!/usr/bin/env bash
set -euo pipefail
P="clab-ot-zone-conduit"

for node in idmz-fw site-rtr; do
  docker exec "$P-$node" nft -f /opt/ot/solution.nft
  docker exec "$P-$node" sh -c \
    'rm -f /run/ot/firewall.log; if test -f /run/ulogd.pid; then kill "$(cat /run/ulogd.pid)" 2>/dev/null || true; fi; ulogd -d -p /run/ulogd.pid -c /opt/ot/ulogd.conf'
done
for node in plc1 plc2; do
  docker exec "$P-$node" nft -f /opt/ot/solution.nft
  docker exec "$P-$node" rm -f /run/ot/maintenance.enabled
done
docker exec "$P-jump" bash /opt/ot/enable-ssh.sh
docker exec "$P-eng-ws" bash /opt/ot/enable-ssh.sh
docker exec "$P-ids" sh -c \
  'rm -f /run/ot/eve.json; pkill suricata 2>/dev/null || true; suricata -D --runmode=single -i eth1 -S /opt/ot/ot.rules --set app-layer.protocols.modbus.enabled=yes --set outputs.1.eve-log.enabled=yes --set outputs.1.eve-log.filename=eve.json -l /run/ot'

echo "OT conduit policy, jump workflow, PLC guards, and passive IDS are active."
