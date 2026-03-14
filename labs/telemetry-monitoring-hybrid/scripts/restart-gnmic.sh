#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

prefix="$(lab_prefix)"

docker restart "${prefix}-gnmic" >/dev/null
sleep 3
curl -s 'http://127.0.0.1:9090/api/v1/query?query=count%20by%20(target)%20(interfaces_interface_state_counters_in_octets%7Binterface_name%3D~%22Ethernet.*%22%7D)' | jq .
