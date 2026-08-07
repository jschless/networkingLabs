#!/usr/bin/env bash
# Restore the telemetry sensor after the Break-It task.
set -euo pipefail

container=clab-network-assurance-sensor

if ! docker inspect "$container" >/dev/null 2>&1; then
    echo "ERROR: network-assurance is not deployed" >&2
    exit 1
fi

docker exec "$container" bash /opt/assurance/start-sensor.sh
docker exec "$container" sh -c '
  test -s /run/softflowd.pid
  test -S /run/softflowd.ctl
  kill -0 "$(cat /run/softflowd.pid)"
  softflowctl -c /run/softflowd.ctl statistics >/dev/null
'

echo "Telemetry sensor restored and verified."
