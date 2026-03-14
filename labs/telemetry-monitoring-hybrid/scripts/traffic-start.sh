#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

duration="${1:-30}"
prefix="$(lab_prefix)"

echo "Starting iperf3 from ${prefix}-client to 10.20.20.11 for ${duration}s"
docker exec "${prefix}-client" iperf3 -c 10.20.20.11 -t "${duration}"
