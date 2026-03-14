#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_full_profile

base_url="http://127.0.0.1:8980/opennms/rest"
auth="admin:admin"

echo "Nodes:"
curl -s -u "${auth}" "${base_url}/nodes?limit=20" | sed 's/></>\n</g'
echo
echo "Recent events:"
curl -s -u "${auth}" "${base_url}/events?limit=10" | sed 's/></>\n</g' | sed -n '1,120p'
echo
echo "Current outages:"
curl -s -u "${auth}" "${base_url}/outages?limit=20" | sed 's/></>\n</g'
