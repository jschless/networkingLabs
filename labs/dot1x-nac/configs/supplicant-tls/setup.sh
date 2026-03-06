#!/bin/bash
# supplicant-tls/setup.sh — EAP-TLS supplicant (alice-tls, employee, VLAN 10)
#
# Pre-configured: certs are bind-mounted at /etc/certs/
# The lab starts wpa_supplicant automatically so auth happens on deploy.
# Users can restart wpa_supplicant manually to re-observe the exchange.

set -e

ip link set eth1 up
ip addr add 10.10.10.11/24 dev eth1 2>/dev/null || true

# Write wpa_supplicant config
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

# Wait briefly for authenticator to finish setup, then start wpa_supplicant
sleep 3
wpa_supplicant -D wired -i eth1 -c /etc/wpa_supplicant/wpa_supplicant.conf \
    -B -P /var/run/wpa_supplicant-eth1.pid -f /var/log/wpa_supplicant.log

echo "[supplicant-tls] wpa_supplicant started (EAP-TLS, identity=alice-tls)"
echo "[supplicant-tls] Watch: docker exec clab-dot1x-nac-supplicant-tls tail -f /var/log/wpa_supplicant.log"
