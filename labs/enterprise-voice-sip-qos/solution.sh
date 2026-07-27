#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
P="clab-enterprise-voice-sip-qos"

for node in access1 dist1 dns-ntp phone-a traffic-gen pbx wan-edge; do
    docker inspect "$P-$node" >/dev/null
done

docker exec -i "$P-access1" Cli -p 15 <<'EOS'
enable
configure
vlan 10
 name DATA
vlan 20
 name VOICE
vlan 30
 name VOICE-SERVICES
interface Ethernet1
 switchport access vlan 20
 spanning-tree portfast edge
interface Ethernet2
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30
interface Ethernet3
 switchport access vlan 30
 spanning-tree portfast edge
interface Ethernet4
 switchport access vlan 10
 spanning-tree portfast edge
interface Ethernet5
 switchport access vlan 30
 spanning-tree portfast edge
end
EOS

docker exec -i "$P-dist1" Cli -p 15 <<'EOS'
enable
configure
ip routing
vlan 10
 name DATA
vlan 20
 name VOICE
vlan 30
 name VOICE-SERVICES
interface Ethernet1
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30
interface Ethernet2
 switchport access vlan 30
 spanning-tree portfast edge
interface Ethernet4
 no switchport
 ip address 192.0.2.109/30
interface Vlan10
 ip address 10.109.10.1/24
 ip helper-address 10.109.30.53
interface Vlan20
 ip address 10.109.20.1/24
 ip helper-address 10.109.30.53
interface Vlan30
 ip address 10.109.30.1/24
ip route 10.109.40.0/24 192.0.2.110
ip route 198.51.100.108/30 192.0.2.110
ip access-list DATA-BOUNDARY
 10 deny ip 10.109.20.0/24 any
 20 deny ip 10.109.30.0/24 any
 30 deny udp any host 10.109.30.10 eq 5060
 40 deny tcp any host 10.109.30.10 eq 5038
 50 deny tcp any host 10.109.30.10 eq 8088
 90 permit ip any any
end
EOS

docker exec -i "$P-dns-ntp" sh -e <<'SERVICES'
cat >/etc/dnsmasq.d/voice.conf <<'EOF'
interface=eth1
bind-interfaces
domain=voice.lab
local=/voice.lab/
address=/pbx.voice.lab/10.109.30.10
srv-host=_sip._udp.voice.lab,pbx.voice.lab,5060,0,0
dhcp-authoritative
dhcp-range=set:data,10.109.10.100,10.109.10.199,255.255.255.0,1h
dhcp-range=set:voice,10.109.20.100,10.109.20.199,255.255.255.0,1h
dhcp-option=tag:data,option:router,10.109.10.1
dhcp-option=tag:voice,option:router,10.109.20.1
dhcp-option=option:dns-server,10.109.30.53
dhcp-option=tag:voice,option:ntp-server,10.109.30.53
dhcp-option=tag:voice,66,pbx.voice.lab
log-dhcp
log-queries
log-facility=/var/log/dnsmasq.log
EOF
cat >/etc/chrony/chrony.conf <<'EOF'
local stratum 8
allow 10.109.0.0/16
bindaddress 10.109.30.53
driftfile /var/lib/chrony/drift
logdir /var/log/chrony
EOF
pkill dnsmasq 2>/dev/null || true
pkill chronyd 2>/dev/null || true
sleep 1
dnsmasq --conf-file=/etc/dnsmasq.d/voice.conf
chronyd -f /etc/chrony/chrony.conf
printf 'HEALTHY\n' >/run/voice/services-state
SERVICES

for node in phone-a traffic-gen; do
    docker exec "$P-$node" sh -c \
      'dhclient -r eth1 >/dev/null 2>&1 || true; rm -f /var/lib/dhcp/dhclient*.leases; dhclient -v eth1'
done
PHONE_A_IP="$(docker exec "$P-phone-a" ip -4 -o addr show dev eth1 | awk '{print $4}' | cut -d/ -f1)"
DATA_IP="$(docker exec "$P-traffic-gen" ip -4 -o addr show dev eth1 | awk '{print $4}' | cut -d/ -f1)"
docker exec "$P-phone-a" ip route replace default via 10.109.20.1 dev eth1 src "$PHONE_A_IP"
docker exec "$P-traffic-gen" ip route replace default via 10.109.10.1 dev eth1 src "$DATA_IP"

docker exec "$P-pbx" nft delete table inet pbx_guard 2>/dev/null || true
docker exec -i "$P-pbx" nft -f - <<'NFT'
table inet pbx_guard {
  chain input {
    type filter hook input priority filter; policy accept;
    iifname "eth1" ip saddr 10.109.10.0/24 udp dport 5060 counter drop
    iifname "eth1" ip saddr 10.109.10.0/24 tcp dport { 5038, 8088 } counter drop
  }
}
NFT

docker exec "$P-wan-edge" nft delete table ip voice_edge 2>/dev/null || true
docker exec -i "$P-wan-edge" nft -f - <<'NFT'
table ip voice_edge {
  counter untrusted_ef {}
  chain remark {
    type filter hook prerouting priority mangle; policy accept;
    ip saddr 10.109.10.0/24 ip dscp ef counter name untrusted_ef ip dscp set cs0
  }
  chain prerouting_nat {
    type nat hook prerouting priority dstnat; policy accept;
    iifname "eth2" ip daddr 192.0.2.110 udp dport 5060 dnat to 10.109.30.10
    iifname "eth2" ip daddr 192.0.2.110 udp dport 10000-10099 dnat to 10.109.30.10
  }
  chain forward_filter {
    type filter hook forward priority filter; policy drop;
    ct state established,related accept
    ct status dnat udp dport 5060 accept
    ct status dnat udp dport 10000-10099 accept
    iifname "eth1" oifname "eth2" ip saddr 10.109.30.10 ip daddr 10.109.40.20 udp dport { 5060, 6002 } accept
    iifname "eth1" oifname "eth2" ip saddr 10.109.10.0/24 ip daddr 10.109.40.20 udp dport 5201 accept
    iifname "eth1" oifname "eth2" ip saddr 10.109.10.0/24 ip daddr 10.109.40.20 tcp dport 5201 accept
    ip protocol icmp accept
  }
  chain postrouting_nat {
    type nat hook postrouting priority srcnat; policy accept;
    oifname "eth2" ip saddr 10.109.30.10 ip daddr 10.109.40.20 udp dport { 5060, 6002 } snat to 192.0.2.110
  }
}
NFT

docker exec "$P-wan-edge" sh -c '
tc qdisc del dev eth2 root 2>/dev/null || true
tc qdisc add dev eth2 root handle 1: htb default 20
tc class add dev eth2 parent 1: classid 1:1 htb rate 1mbit ceil 1mbit burst 15k
tc class add dev eth2 parent 1:1 classid 1:10 htb rate 256kbit ceil 1mbit burst 15k prio 0
tc class add dev eth2 parent 1:1 classid 1:20 htb rate 744kbit ceil 1mbit burst 15k prio 2
tc qdisc add dev eth2 parent 1:10 handle 10: pfifo limit 100
tc qdisc add dev eth2 parent 1:20 handle 20: fq_codel
tc filter add dev eth2 protocol ip parent 1: prio 10 u32 match ip dsfield 0xb8 0xfc flowid 1:10
tc filter add dev eth2 protocol ip parent 1: prio 11 u32 match ip dsfield 0x60 0xfc flowid 1:10
printf "POLICY_ACTIVE\n" >/run/voice/edge-state
'

"$LAB_DIR/register-endpoints.sh"
echo "Reference end state applied."
