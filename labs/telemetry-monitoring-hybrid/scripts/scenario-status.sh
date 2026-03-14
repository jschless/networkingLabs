#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

prefix="$(lab_prefix)"

echo "Profile: ${prefix#clab-telemetry-monitoring-}"
echo
echo "Containers:"
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep "${prefix}" || true
echo
echo "Path check:"
docker exec "${prefix}-client" ping -c 2 10.20.20.11 || true
echo
echo "Prometheus scrape:"
curl -s http://127.0.0.1:9090/api/v1/query?query=up
echo
