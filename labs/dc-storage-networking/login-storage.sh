#!/usr/bin/env bash
set -euo pipefail

I="clab-dc-storage-networking-initiator1"
IQN="iqn.2026-07.lab.example:dc-storage"
VM=(docker exec "$I" vm-exec)

"${VM[@]}" sudo iscsiadm -m discovery -t sendtargets -p 10.111.10.20
"${VM[@]}" sudo iscsiadm -m discovery -t sendtargets -p 10.111.20.20
for portal in 10.111.10.20:3260 10.111.20.20:3260; do
  "${VM[@]}" sudo iscsiadm -m node -T "$IQN" -p "$portal" \
    --op update -n node.session.auth.authmethod -v CHAP
  "${VM[@]}" sudo iscsiadm -m node -T "$IQN" -p "$portal" \
    --op update -n node.session.auth.username -v labinitiator
  "${VM[@]}" sudo iscsiadm -m node -T "$IQN" -p "$portal" \
    --op update -n node.session.auth.password -v 'LAB-Storage-26!'
  "${VM[@]}" sudo iscsiadm -m node -T "$IQN" -p "$portal" --login \
    || "${VM[@]}" sudo iscsiadm -m session | grep -q "$portal"
done

[[ "$("${VM[@]}" sudo iscsiadm -m session | grep -c "$IQN" || true)" -eq 2 ]]
