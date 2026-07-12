#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-corp1 ping -c 2 -W 2 10.250.50.10 >/dev/null
echo 'PASS: corporate-to-branch routing is restored.'
