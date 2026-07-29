#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-dci-edge

docker exec "$prefix-carrier-test-a" ping -I eth1.110 -c 1 -W 2 192.0.2.2 >/dev/null
docker exec "$prefix-carrier-test-a" ping -I eth1.120 -c 1 -W 2 198.51.100.2 >/dev/null
docker exec "$prefix-carrier-test-b" ping -I eth1.110 -c 1 -W 2 192.0.2.1 >/dev/null
docker exec "$prefix-carrier-test-b" ping -I eth1.120 -c 1 -W 2 198.51.100.1 >/dev/null
docker exec "$prefix-carrier-test-a" ping -I eth1.110 -M "do" -c 1 -W 2 -s 1572 192.0.2.2 >/dev/null

flows="$(docker exec "$prefix-carrier-nid-b" ovs-ofctl -O OpenFlow13 dump-flows br-service)"
grep -q 'dl_vlan=110.*set_field:7196->vlan_vid' <<<"$flows"
grep -q 'dl_vlan=120.*set_field:7216->vlan_vid' <<<"$flows"
if grep -q 'dl_vlan=120.*set_field:7196->vlan_vid' <<<"$flows"; then
    echo "ERROR: Silver is mapped onto the Gold provider service" >&2
    exit 1
fi
if grep -Eq 'actions=(NORMAL|FLOOD)' <<<"$flows"; then
    echo "ERROR: broad bridge forwarding bypasses explicit service mappings" >&2
    exit 1
fi
echo "PASS: Gold and Silver pass bidirectionally at the committed MTU, retain distinct service mappings, and no broad bridge workaround exists."
