#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_full_profile

base_url="http://127.0.0.1:8980/opennms/rest"
auth="admin:admin"

node_id="$(curl -s -u "${auth}" "${base_url}/nodes?label=core1" | sed -n 's/.*<node[^>]*id="\([0-9]\+\)".*label="core1".*/\1/p' | head -n1)"

if [[ -z "${node_id}" ]]; then
    echo "core1 is not present in OpenNMS yet." >&2
    exit 1
fi

echo "core1 node id: ${node_id}"
echo
echo "IP interfaces:"
curl -s -u "${auth}" "${base_url}/nodes/${node_id}/ipinterfaces" | sed 's/></>\n</g' | sed -n '1,140p'
echo
echo "SNMP interfaces:"
curl -s -u "${auth}" "${base_url}/nodes/${node_id}/snmpinterfaces" | sed 's/></>\n</g' | sed -n '1,140p'
