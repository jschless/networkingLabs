#!/bin/bash
set -e

echo 1 > /proc/sys/net/ipv4/ip_forward
ip link set eth1 up
ip link set eth2 up
ip link set eth1 mtu 1500

/usr/lib/frr/frrinit.sh start
sleep 2
vtysh -b

cat > /etc/snmp/snmpd.conf << 'EOF'
agentAddress udp:0.0.0.0:161
rocommunity public
sysName pe1
sysLocation "telemetry-monitoring-hybrid"
EOF
snmpd -C -c /etc/snmp/snmpd.conf -Lf /var/log/snmpd.log

echo "[pe1] FRR + SNMP ready"
