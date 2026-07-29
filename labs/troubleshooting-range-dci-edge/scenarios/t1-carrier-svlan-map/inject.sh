#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-dci-edge
dir="$(cd "$(dirname "$0")" && pwd)"

"$dir/clear.sh"
docker exec "$prefix-carrier-nid-b" ovs-ofctl -O OpenFlow13 del-flows br-service
docker exec "$prefix-carrier-nid-b" ovs-ofctl -O OpenFlow13 add-flow br-service \
    "priority=100,in_port=1,dl_vlan=110,actions=push_vlan:0x88a8,set_field:0x1c1c->vlan_vid,set_field:5->vlan_pcp,output:2"
docker exec "$prefix-carrier-nid-b" ovs-ofctl -O OpenFlow13 add-flow br-service \
    "priority=100,in_port=1,dl_vlan=120,actions=push_vlan:0x88a8,set_field:0x1f9f->vlan_vid,set_field:3->vlan_pcp,output:2"
docker exec "$prefix-carrier-nid-b" ovs-ofctl -O OpenFlow13 add-flow br-service \
    "priority=100,in_port=2,dl_vlan=3100,actions=pop_vlan,output:1"
docker exec "$prefix-carrier-nid-b" ovs-ofctl -O OpenFlow13 add-flow br-service \
    "priority=100,in_port=2,dl_vlan=3120,actions=pop_vlan,output:1"

if docker exec "$prefix-carrier-test-a" ping -I eth1.120 -c 1 -W 2 198.51.100.2 >/dev/null 2>&1; then
    echo "ERROR: Silver symptom was not established" >&2
    exit 1
fi
docker exec "$prefix-carrier-test-a" ping -I eth1.110 -c 1 -W 2 192.0.2.2 >/dev/null
docker exec "$prefix-carrier-test-a" ping -I eth1.110 -M "do" -c 1 -W 2 -s 1572 192.0.2.2 >/dev/null
echo "Ticket symptom is active: Silver is unavailable while Gold and its committed MTU remain healthy."
