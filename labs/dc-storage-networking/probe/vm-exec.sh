#!/usr/bin/env bash
set -euo pipefail

exec ssh -i /run/storage-vm/id_ed25519 \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  storage@10.111.30.10 "$@"
