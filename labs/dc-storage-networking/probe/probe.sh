#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LAB="$ROOT/labs/dc-storage-networking"
TOPO="$LAB/probe/topology.clab.yml"
I="clab-dc-storage-probe-initiator"
T="clab-dc-storage-probe-target"
IQN="iqn.2026-07.lab.example:dc-storage"

cleanup() {
  docker exec "$I" vm-exec sudo iscsiadm -m node -T "$IQN" --logout >/dev/null 2>&1 || true
  docker exec "$I" vm-exec sudo multipath -F >/dev/null 2>&1 || true
  docker exec "$T" targetcli /iscsi delete "$IQN" >/dev/null 2>&1 || true
  docker exec "$T" targetcli /backstores/fileio delete storage-lun >/dev/null 2>&1 || true
  containerlab destroy --topo "$TOPO" --cleanup >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker build -t dc-storage-tools:1.0.0 "$LAB"
containerlab deploy --topo "$TOPO"

for _ in $(seq 1 20); do
  if docker exec "$T" targetcli /iscsi ls | grep -q "$IQN"; then
    break
  fi
  sleep 1
done

docker exec "$I" vm-exec sudo iscsiadm -m discovery -t sendtargets -p 10.111.10.20
docker exec "$I" vm-exec sudo iscsiadm -m discovery -t sendtargets -p 10.111.20.20
docker exec "$I" vm-exec sudo iscsiadm -m node -T "$IQN" -p 10.111.10.20:3260 --login
docker exec "$I" vm-exec sudo iscsiadm -m node -T "$IQN" -p 10.111.20.20:3260 --login

for _ in $(seq 1 20); do
  if [[ "$(docker exec "$I" vm-exec sudo iscsiadm -m session 2>/dev/null | grep -c "$IQN" || true)" -eq 2 ]]; then
    break
  fi
  sleep 1
done

docker exec "$I" vm-exec sudo multipath -r
docker exec "$I" vm-exec sudo iscsiadm -m session -P 1
docker exec "$I" vm-exec sudo multipath -ll
docker exec "$I" vm-exec sudo lsblk -S -o NAME,VENDOR,MODEL,SERIAL,TRAN
docker exec "$I" vm-exec ping -M 'do' -s 8972 -c 2 -W 2 10.111.10.20

MAP="$(docker exec "$I" vm-exec sudo multipath -ll | awk '/dm-[0-9]+/{print $1; exit}')"
test -n "$MAP"
docker exec "$I" vm-exec sudo bash -c "'dd if=/dev/mapper/$MAP of=/tmp/probe.bin bs=1M count=8 iflag=direct status=none'"
docker exec "$I" vm-exec sha256sum /tmp/probe.bin

docker exec "$I" ip link set eth1 down
docker exec "$I" vm-exec sudo bash -c "'dd if=/dev/mapper/$MAP of=/tmp/probe-after-fail.bin bs=1M count=8 iflag=direct status=none'"
docker exec "$I" vm-exec cmp /tmp/probe.bin /tmp/probe-after-fail.bin
docker exec "$I" vm-exec sudo multipath -ll
docker exec "$I" ip link set eth1 up
docker exec "$I" vm-exec ping -c 1 -W 2 10.111.10.20
docker exec "$I" vm-exec sudo iscsiadm -m session -R
sleep 2
docker exec "$I" vm-exec sudo multipath -ll

docker exec "$I" ip link set eth1 mtu 1500
docker exec "$I" vm-exec ping -c 1 -W 2 10.111.10.20
if docker exec "$I" vm-exec ping -M 'do' -s 8972 -c 1 -W 2 10.111.10.20; then
  echo "ERROR: mismatched-MTU large probe unexpectedly passed" >&2
  exit 1
fi
docker exec "$I" ip link set eth1 mtu 9000
docker exec "$I" vm-exec ping -M 'do' -s 8972 -c 1 -W 2 10.111.10.20

docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' "$I" "$T"
echo "PROBE PASS: two sessions, multipath failover, exact MTU failure/recovery"
