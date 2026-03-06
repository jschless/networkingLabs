#!/bin/bash
# r1 — OSPF router with SNMP, syslog, and NetFlow enabled
set -e

echo 1 > /proc/sys/net/ipv4/ip_forward
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up

# Start FRR (interfaces and IPs managed by frr.conf)
/usr/lib/frr/frrinit.sh start
sleep 2
vtysh -b

# SNMPd — v2c community + v3 user
cat > /etc/snmp/snmpd.conf << 'EOF'
agentAddress udp:0.0.0.0:161
rocommunity  public  172.16.0.0/16
rocommunity  public  127.0.0.1
createUser   snmpv3user SHA authpass123 AES privpass456
rouser       snmpv3user priv
sysName      r1
sysLocation  "ContainerLab network-assurance"
EOF
snmpd -C -c /etc/snmp/snmpd.conf -Lf /var/log/snmpd.log

# Syslog — forward to management (172.16.0.2)
cat > /etc/rsyslog.d/50-remote.conf << 'EOF'
*.* @172.16.0.2:514
EOF
rsyslogd

# NetFlow v5 — export to management UDP 2055
softflowd -i eth2 -n 172.16.0.2:2055 -v 5 -P udp

echo "[r1] OSPF, SNMPd (161), syslog→172.16.0.2:514, NetFlow→172.16.0.2:2055 active"
