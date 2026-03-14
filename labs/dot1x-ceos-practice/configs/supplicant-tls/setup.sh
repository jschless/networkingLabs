#!/bin/bash

set -e

ip link set eth1 up
ip addr add 10.10.10.11/24 dev eth1 2>/dev/null || true

mkdir -p /etc/wpa_supplicant
cat > /etc/wpa_supplicant/wpa_supplicant.conf << 'EOF'
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=0

network={
    key_mgmt=IEEE8021X
    eap=TLS
    identity="alice-tls"
    ca_cert="/etc/certs/ca.pem"
    client_cert="/etc/certs/client.pem"
    private_key="/etc/certs/client.key"
    eapol_flags=0
}
EOF

sleep 5
wpa_supplicant -D wired -i eth1 -c /etc/wpa_supplicant/wpa_supplicant.conf \
    -B -P /var/run/wpa_supplicant-eth1.pid -f /var/log/wpa_supplicant.log

echo "[supplicant-tls] wpa_supplicant started (EAP-TLS)"
