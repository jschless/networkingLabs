#!/usr/bin/env bash
# Inject the lab's opaque, single-plane telemetry fault.
set -euo pipefail

container=clab-network-assurance-sensor

if ! docker inspect "$container" >/dev/null 2>&1; then
    echo "ERROR: network-assurance is not deployed" >&2
    exit 1
fi

docker exec "$container" sh -c '
  if [ -s /run/softflowd.pid ] && kill -0 "$(cat /run/softflowd.pid)" 2>/dev/null; then
    kill "$(cat /run/softflowd.pid)"
  fi
  attempt=0
  while [ "$attempt" -lt 50 ] && ps -eo stat=,comm= | awk \
    '\''$2 == "softflowd" && $1 !~ /^Z/ { found = 1 } END { exit !found }'\''; do
    attempt=$((attempt + 1))
    sleep 0.1
  done
  rm -f /run/softflowd.pid /run/softflowd.ctl
  ! ps -eo stat=,comm= | awk \
    '\''$2 == "softflowd" && $1 !~ /^Z/ { found = 1 } END { exit !found }'\''
'

echo "A telemetry fault was injected. Diagnose which evidence plane is missing."
