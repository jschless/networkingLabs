#!/usr/bin/env bash
set -euo pipefail
ip addr replace 10.250.10.1/24 dev eth1
ip addr replace 10.250.20.1/24 dev eth2
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
sysctl -q -w net.ipv4.ip_forward=1

nft -f - <<'EOF'
flush ruleset
table inet probe {
  counter permit_modbus {}
  counter deny_other {}
  chain forward {
    type filter hook forward priority filter; policy drop;
    ct state invalid counter name deny_other log group 100 prefix "OT-RULE-090 invalid " drop
    ct state established,related counter accept comment "OT-RULE-101 stateful-return"
    iifname "eth1" oifname "eth2" ip saddr 10.250.10.2 ip daddr 10.250.20.2 tcp dport 502 ct state new counter name permit_modbus log group 100 prefix "OT-RULE-100 modbus " accept
    counter name deny_other log group 100 prefix "OT-RULE-199 default-deny " drop
  }
}
EOF
install -d /run/ot-probe
ulogd -d -c /opt/probe/ulogd.conf

for iface in eth1 eth2; do
  tc qdisc replace dev "$iface" clsact
  tc filter replace dev "$iface" ingress matchall \
    action mirred egress mirror dev eth3
done
