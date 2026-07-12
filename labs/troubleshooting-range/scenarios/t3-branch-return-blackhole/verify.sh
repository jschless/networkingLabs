#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-branch-client ping -c 2 -W 2 10.250.40.10 >/dev/null
echo 'PASS: branch-to-services return path is restored.'
