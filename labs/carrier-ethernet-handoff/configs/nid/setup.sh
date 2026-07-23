#!/usr/bin/env bash
set -euo pipefail
for iface in eth1 eth2; do ip link set "$iface" mtu 1608 up; done
ovs-vsctl add-br br-service -- set bridge br-service datapath_type=netdev protocols=OpenFlow13 fail-mode=secure
ovs-vsctl add-port br-service eth1
ovs-vsctl add-port br-service eth2
