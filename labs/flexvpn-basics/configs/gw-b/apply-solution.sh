#!/usr/bin/env bash
set -euo pipefail

ipsec stop >/dev/null 2>&1 || true
ip xfrm state flush 2>/dev/null || true
ip xfrm policy flush 2>/dev/null || true
ip tunnel del vti0 2>/dev/null || true

cat >/etc/ipsec.conf <<'EOF'
config setup
    uniqueids=yes

conn to-hub
    keyexchange=ikev2
    authby=secret
    type=tunnel
    ike=aes256-sha256-modp2048!
    esp=aes256gcm16-modp2048!
    dpdaction=restart
    dpddelay=30s
    left=203.0.113.6
    leftid=@spoke1
    leftsubnet=0.0.0.0/0
    right=203.0.113.1
    rightid=@hub
    rightsubnet=0.0.0.0/0
    mark=1
    auto=start
EOF
cat >/etc/ipsec.secrets <<'EOF'
@spoke1 @hub : PSK "RouteBased-IKEv2-Lab"
EOF
chmod 0600 /etc/ipsec.secrets

ip tunnel add vti0 mode vti local 203.0.113.6 remote 203.0.113.1 key 1
ip link set vti0 up
ip address replace 10.10.1.2/30 dev vti0
sysctl -qw net.ipv4.conf.vti0.disable_policy=1
sysctl -qw net.ipv4.conf.vti0.rp_filter=0
ip route replace 192.168.1.0/24 via 10.10.1.1 dev vti0
ip route replace 192.168.3.0/24 via 10.10.1.1 dev vti0
ipsec start
