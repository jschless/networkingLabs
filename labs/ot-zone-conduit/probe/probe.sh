#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOPO="$LAB_DIR/probe/topology.clab.yml"
PREFIX="clab-ot-zone-conduit-probe"

cleanup() {
  containerlab destroy -t "$TOPO" --cleanup >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

/usr/bin/time -f 'build elapsed=%e max_rss_kib=%M' \
  docker build -t ot-zone-tools:1.0.0 "$LAB_DIR"
/usr/bin/time -f 'deploy elapsed=%e max_rss_kib=%M' \
  containerlab deploy -t "$TOPO"

for _ in $(seq 1 30); do
  if docker exec "$PREFIX-client" nc -z -w1 10.250.20.2 502; then
    break
  fi
  sleep 1
done

INITIAL="$(docker exec "$PREFIX-client" python3 /opt/probe/client.py read)"
AFTER_WRITE="$(docker exec "$PREFIX-client" python3 /opt/probe/client.py write)"
echo "initial=$INITIAL"
echo "after_write=$AFTER_WRITE"
grep -q '"line_speed_rpm": 420, "tank_level_pct": 73' <<<"$INITIAL"
grep -q '"line_speed_rpm": 420, "tank_level_pct": 88' <<<"$AFTER_WRITE"

docker exec "$PREFIX-client" ip addr add 10.250.10.99/24 dev eth1
if docker exec "$PREFIX-client" \
  nc -z -w1 -s 10.250.10.99 10.250.20.2 502; then
  echo "ERROR: default-deny test unexpectedly connected" >&2
  exit 1
fi
docker exec "$PREFIX-client" ip addr del 10.250.10.99/24 dev eth1
echo "unauthorized_source=denied"
sleep 2
docker exec "$PREFIX-fw" nft list ruleset
docker exec "$PREFIX-fw" cat /run/ot-probe/firewall.log
docker exec "$PREFIX-fw" grep -q 'OT-RULE-100 modbus' /run/ot-probe/firewall.log
docker exec "$PREFIX-fw" grep -q 'OT-RULE-199 default-deny' /run/ot-probe/firewall.log
docker exec "$PREFIX-sensor" jq -c \
  'select(.event_type == "alert") | {event_type,app_proto,signature:.alert.signature}' \
  /run/ot-probe/eve.json
docker exec "$PREFIX-sensor" grep -q \
  'LAB-OT Modbus single-register write observed' /run/ot-probe/eve.json
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' \
  "$PREFIX-client" "$PREFIX-fw" "$PREFIX-plc" "$PREFIX-sensor"
docker stop "$PREFIX-sensor" >/dev/null
echo "sensor_stopped_read=$(docker exec "$PREFIX-client" python3 /opt/probe/client.py read)"

containerlab destroy -t "$TOPO" --cleanup
/usr/bin/time -f 'redeploy elapsed=%e max_rss_kib=%M' \
  containerlab deploy -t "$TOPO"
for _ in $(seq 1 30); do
  if docker exec "$PREFIX-client" nc -z -w1 10.250.20.2 502; then
    break
  fi
  sleep 1
done
RESET="$(docker exec "$PREFIX-client" python3 /opt/probe/client.py read)"
echo "reset=$RESET"
grep -q '"line_speed_rpm": 420, "tank_level_pct": 73' <<<"$RESET"
