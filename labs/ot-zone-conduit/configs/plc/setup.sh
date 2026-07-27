#!/usr/bin/env bash
set -euo pipefail
install -d /run/ot
ip addr replace "$IP_ADDR" dev eth1
ip link set eth1 up
ip route replace default via "$GATEWAY"
printf '{"line_speed_rpm":%s,"tank_level_pct":%s}\n' \
  "$LINE_SPEED" "$TANK_LEVEL" >/run/ot/initial.json
: >/run/ot/plc-events.jsonl
python3 /opt/ot/modbus-server \
  --listen 0.0.0.0 --port 502 --state /run/ot/initial.json \
  --event-log /run/ot/plc-events.jsonl \
  --maintenance-flag /run/ot/maintenance.enabled \
  >/run/ot/modbus.log 2>&1 &
