#!/usr/bin/env bash
set -euo pipefail

I="clab-dc-storage-networking-initiator1"
VM=(docker exec "$I" vm-exec)
MAP="$("${VM[@]}" sudo multipath -ll | awk '/dm-[0-9]+/{print $1; exit}')"
[[ -n "$MAP" ]]

"${VM[@]}" sudo bash -c \
  "'dd if=/dev/urandom of=/tmp/storage-payload.bin bs=1M count=8 status=none; \
  dd if=/tmp/storage-payload.bin of=/dev/mapper/$MAP bs=1M seek=8 oflag=direct conv=fsync status=none; \
  dd if=/dev/mapper/$MAP of=/tmp/storage-readback.bin bs=1M skip=8 count=8 iflag=direct status=none; \
  cmp /tmp/storage-payload.bin /tmp/storage-readback.bin; \
  sha256sum /tmp/storage-payload.bin /tmp/storage-readback.bin'"
