#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="clab-dc-storage-networking"
IQN="iqn.2026-07.lab.example:dc-storage"

docker exec "$P-initiator1" vm-exec sudo iscsiadm -m node -T "$IQN" --logout \
  >/dev/null 2>&1 || true
docker exec "$P-initiator1" vm-exec sudo multipath -F >/dev/null 2>&1 || true
docker exec "$P-target1" targetcli /iscsi delete "$IQN" >/dev/null 2>&1 || true
docker exec "$P-target1" targetcli /backstores/fileio delete storage-lun >/dev/null 2>&1 || true
docker exec "$P-target1" rm -f /var/lib/storage/lun.img >/dev/null 2>&1 || true
"$ROOT/scripts/lab.sh" destroy dc-storage-networking

if docker ps -a --format '{{.Names}}' | grep -q "^$P-"; then
  echo "ERROR: scoped containers remain" >&2
  exit 1
fi
if [[ -d /sys/kernel/config/target/iscsi/$IQN ]]; then
  echo "ERROR: scoped LIO target remains" >&2
  exit 1
fi
echo "Cleanup PASS: no dc-storage-networking containers, mappings, target, or backing file remain."
