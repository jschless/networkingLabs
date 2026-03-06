#!/bin/bash
# management — central collector: syslog server, NetFlow collector, SNMP poller
#
# Interfaces:
#   eth1  172.16.0.2/30   to r1
#   eth2  172.16.0.6/30   to r2
#   eth3  172.16.0.10/30  to r3
#   eth4  192.168.99.1/30 to analyzer (SPAN forwarding)
set -e

ip link set eth1 up && ip addr add 172.16.0.2/30  dev eth1
ip link set eth2 up && ip addr add 172.16.0.6/30  dev eth2
ip link set eth3 up && ip addr add 172.16.0.10/30 dev eth3
ip link set eth4 up && ip addr add 192.168.99.1/30 dev eth4

# Routes to router loopbacks
ip route add 10.0.0.1/32 via 172.16.0.1
ip route add 10.0.0.2/32 via 172.16.0.5
ip route add 10.0.0.3/32 via 172.16.0.9

# Routes to data subnets (for end-to-end SNMP reachability)
ip route add 10.1.0.0/30  via 172.16.0.1
ip route add 10.3.0.0/30  via 172.16.0.9
ip route add 10.0.12.0/30 via 172.16.0.1
ip route add 10.0.23.0/30 via 172.16.0.5

# Central syslog — receive UDP 514 from all routers
cat > /etc/rsyslog.conf << 'EOF'
module(load="imudp")
input(type="imudp" port="514")

$template RemoteLogs,"/var/log/remote/%HOSTNAME%.log"
if $fromhost-ip != '127.0.0.1' then ?RemoteLogs
& stop

*.* /var/log/syslog
EOF
mkdir -p /var/log/remote
rsyslogd

# NetFlow collector — receive UDP 2055, write files to /var/log/netflow/
mkdir -p /var/log/netflow
nfcapd -D -l /var/log/netflow -p 2055 -P /var/run/nfcapd.pid

# Forward SPAN frames from eth2 (r2 mirrored traffic) to analyzer via eth4
# r2 mirrors eth1→eth3, which arrives here on eth2. We forward to analyzer.
echo 1 > /proc/sys/net/ipv4/ip_forward
tc qdisc add dev eth2 ingress handle ffff: 2>/dev/null || true
tc filter add dev eth2 parent ffff: protocol all u32 match u32 0 0 \
    action mirred egress mirror dev eth4

echo "[management] Ready"
echo "  Syslog:   UDP 514  → /var/log/remote/<hostname>.log"
echo "  NetFlow:  UDP 2055 → /var/log/netflow/ (nfcapd)"
echo "  SPAN:     eth2 (r2 mirror) forwarded to analyzer via eth4"
echo ""
echo "  SNMP poll r1: snmpwalk -v2c -c public 172.16.0.1 ifDescr"
echo "  NetFlow:      nfdump -R /var/log/netflow -s bytes"
echo "  Syslog:       tail -f /var/log/remote/r1.log"
