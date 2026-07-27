#!/usr/bin/env bash
set -euo pipefail

I="clab-dc-storage-networking-initiator1"
docker exec "$I" vm-exec sudo cp \
  /opt/storage/multipath.solution.conf /etc/multipath.conf
docker exec "$I" vm-exec sudo systemctl restart multipathd
for _ in $(seq 1 20); do
  docker exec "$I" vm-exec sudo multipath -r >/dev/null
  if [[ "$(docker exec "$I" vm-exec sudo multipath -ll | grep -c 'active ready running' || true)" -eq 2 ]]; then
    exit 0
  fi
  sleep 1
done
exit 1
