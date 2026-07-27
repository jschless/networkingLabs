#!/usr/bin/env bash
set -euo pipefail
ip link set eth1 up
install -d /run/ot-probe
suricata -D --runmode=single -i eth1 -S /opt/probe/modbus.rules \
  --set app-layer.protocols.modbus.enabled=yes \
  --set outputs.1.eve-log.enabled=yes \
  --set outputs.1.eve-log.filename=eve.json \
  -l /run/ot-probe
