#!/usr/bin/env bash
set -euo pipefail

node="$(hostname)"

reset_test_port() {
    ip link del eth1.110 2>/dev/null || true
    ip link del eth1.120 2>/dev/null || true
    ip addr flush dev eth1
    tc qdisc del dev eth1 root 2>/dev/null || true
    ip link set eth1 mtu 1608 up
    ip link add link eth1 name eth1.110 type vlan id 110
    ip link add link eth1 name eth1.120 type vlan id 120
    ip link set eth1.110 mtu 1600 up
    ip link set eth1.120 mtu 1600 up
}

reset_ovs() {
    local role=$1
    ovs-vsctl --if-exists del-br br-service
    for interface in eth1 eth2; do
        tc qdisc del dev "$interface" root 2>/dev/null || true
        ip link set "$interface" mtu 1608 up
    done
    ovs-vsctl add-br br-service -- set bridge br-service \
        datapath_type=netdev protocols=OpenFlow13 fail-mode=secure
    ovs-vsctl add-port br-service eth1
    ovs-vsctl add-port br-service eth2
    if [[ "$role" == nid ]]; then
        ovs-ofctl -O OpenFlow13 add-flow br-service \
            "priority=100,in_port=1,dl_vlan=110,actions=push_vlan:0x88a8,set_field:0x1c1c->vlan_vid,set_field:5->vlan_pcp,output:2"
        ovs-ofctl -O OpenFlow13 add-flow br-service \
            "priority=100,in_port=1,dl_vlan=120,actions=push_vlan:0x88a8,set_field:0x1c30->vlan_vid,set_field:3->vlan_pcp,output:2"
        ovs-ofctl -O OpenFlow13 add-flow br-service \
            "priority=100,in_port=2,dl_vlan=3100,actions=pop_vlan,output:1"
        ovs-ofctl -O OpenFlow13 add-flow br-service \
            "priority=100,in_port=2,dl_vlan=3120,actions=pop_vlan,output:1"
    else
        for vlan in 3100 3120; do
            ovs-ofctl -O OpenFlow13 add-flow br-service \
                "priority=100,in_port=1,dl_vlan=$vlan,actions=output:2"
            ovs-ofctl -O OpenFlow13 add-flow br-service \
                "priority=100,in_port=2,dl_vlan=$vlan,actions=output:1"
        done
    fi
}

case "$node" in
    carrier-test-a)
        reset_test_port
        ip addr add 192.0.2.1/30 dev eth1.110
        ip addr add 198.51.100.1/30 dev eth1.120
        ;;
    carrier-test-b)
        reset_test_port
        ip addr add 192.0.2.2/30 dev eth1.110
        ip addr add 198.51.100.2/30 dev eth1.120
        ;;
    carrier-nid-a|carrier-nid-b)
        reset_ovs nid
        ;;
    carrier-core)
        reset_ovs core
        ;;
    *)
        echo "unknown carrier range role: $node" >&2
        exit 1
        ;;
esac
