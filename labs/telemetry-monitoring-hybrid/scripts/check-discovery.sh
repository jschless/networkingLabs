#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_full_profile

base_url="http://127.0.0.1:8980/opennms/rest"
auth="admin:admin"

echo "Current nodes:"
curl -s -u "${auth}" "${base_url}/nodes?limit=20" | sed 's/></>\n</g' | sed -n '1,120p'
echo
echo "Check for routed lab nodes:"
for node in branch1 campus1 pe1 core1 dc1; do
    if curl -s -u "${auth}" "${base_url}/nodes?label=${node}" | grep -q "label=\"${node}\""; then
        echo "  OK  ${node}"
    else
        echo "  MISSING  ${node}"
    fi
done
