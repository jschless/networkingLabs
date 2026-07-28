#!/usr/bin/env bash
set -euo pipefail

P="clab-dc-storage-networking"
I="$P-initiator1"
VM=(docker exec "$I" vm-exec)
MAP="$("${VM[@]}" sudo multipath -ll | awk '/dm-[0-9]+/{print $1; exit}')"
[[ -n "$MAP" ]]

docker exec "$P-traffic-gen" sh -c \
  'iperf3 -c 10.111.40.254 -b 40M -t 8 >/tmp/background-iperf.txt 2>&1' &
BG_PID=$!
sleep 1
START="$(date +%s%3N)"
"${VM[@]}" sudo dd "if=/dev/mapper/$MAP" of=/dev/null bs=1M count=8 iflag=direct status=none
END="$(date +%s%3N)"
wait "$BG_PID"
echo "storage_ms=$((END-START)) threshold_ms=10000"
docker exec "$P-tor1" tc -s class show dev eth1
