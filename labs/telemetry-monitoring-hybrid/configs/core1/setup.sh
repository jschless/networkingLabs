#!/bin/bash
# core1 (lite variant) — FRR stand-in for the full variant's cEOS core.
# Same addressing as configs/core1/startup-config so docs stay valid.
set -e

echo 1 > /proc/sys/net/ipv4/ip_forward
ip link set eth1 up
ip link set eth2 up

/usr/lib/frr/frrinit.sh start
sleep 2
vtysh -b

cat > /etc/snmp/snmpd.conf << 'EOF'
master agentx
agentAddress udp:0.0.0.0:161
rocommunity public
sysName core1
sysLocation "telemetry-monitoring-hybrid"
EOF
snmpd -C -c /etc/snmp/snmpd.conf -Lf /var/log/snmpd.log
lldpd -x -I eth1,eth2

echo "[core1] FRR + SNMP + LLDP ready"
