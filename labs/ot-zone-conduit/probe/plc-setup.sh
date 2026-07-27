#!/usr/bin/env bash
set -euo pipefail
ip addr replace 10.250.20.2/24 dev eth1
ip link set eth1 up
ip route replace 10.250.10.0/24 via 10.250.20.1
install -d /run/ot-probe
printf '%s\n' '{"line_speed_rpm":420,"tank_level_pct":73}' >/run/ot-probe/initial.json
python3 /opt/ot/modbus_server.py \
  --listen 0.0.0.0 --port 502 --state /run/ot-probe/initial.json \
  --event-log /run/ot-probe/plc-events.jsonl \
  --maintenance-flag /run/ot-probe/maintenance.enabled \
  >/run/ot-probe/server.log 2>&1 &
touch /run/ot-probe/maintenance.enabled
