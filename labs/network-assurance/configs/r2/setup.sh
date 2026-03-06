#!/bin/bash
# r2 — OSPF router with SNMP, syslog, SPAN, and NetFlow enabled
#
# SPAN: traffic on eth1 is mirrored to eth3 (management link) via tc mirred.
# The management node receives these mirrored frames on its eth2, and forwards
# them to the analyzer via eth4. The analyzer sees duplicated r2:eth1 traffic.
set -e

echo 1 > /proc/sys/net/ipv4/ip_forward
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up

/usr/lib/frr/frrinit.sh start
sleep 2
vtysh -b

cat > /etc/snmp/snmpd.conf << 'EOF'
agentAddress udp:0.0.0.0:161
rocommunity  public  172.16.0.0/16
rocommunity  public  127.0.0.1
createUser   snmpv3user SHA authpass123 AES privpass456
rouser       snmpv3user priv
sysName      r2
sysLocation  "ContainerLab network-assurance"
EOF
snmpd -C -c /etc/snmp/snmpd.conf -Lf /var/log/snmpd.log

cat > /etc/rsyslog.d/50-remote.conf << 'EOF'
*.* @172.16.0.6:514
EOF
rsyslogd

# SPAN: mirror all ingress frames on eth1 to eth3 (management port)
tc qdisc add dev eth1 ingress handle ffff: 2>/dev/null || true
tc filter add dev eth1 parent ffff: protocol all u32 match u32 0 0 \
    action mirred egress mirror dev eth3

# NetFlow v5 — export to management UDP 2055
softflowd -i eth1 -n 172.16.0.6:2055 -v 5 -P udp

echo "[r2] OSPF, SNMPd, syslog→172.16.0.6:514, SPAN eth1→eth3, NetFlow→172.16.0.6:2055 active"
