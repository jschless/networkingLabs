#!/bin/bash
# supplicant-fail/setup.sh — PEAP/MSCHAPv2 with wrong password → RADIUS Reject
#
# Demonstrates Access-Reject: the EAP exchange completes but MSCHAPv2 fails
# because the password doesn't match. The port stays on VLAN 99 (quarantine).
# No IP is assigned because the port never gets authorized.

set -e

ip link set eth1 up
# No IP address — port stays blocked

mkdir -p /etc/wpa_supplicant
cat > /etc/wpa_supplicant/wpa_supplicant.conf << 'EOF'
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=0

network={
    key_mgmt=IEEE8021X
    eap=PEAP
    identity="alice"
    password="wrongpassword"
    phase2="auth=MSCHAPV2"
    ca_cert="/etc/certs/ca.pem"
    eapol_flags=0
}
EOF

sleep 3
wpa_supplicant -D wired -i eth1 -c /etc/wpa_supplicant/wpa_supplicant.conf \
    -B -P /var/run/wpa_supplicant-eth1.pid -f /var/log/wpa_supplicant.log

echo "[supplicant-fail] wpa_supplicant started (PEAP, wrong password — will be REJECTED)"
echo "[supplicant-fail] Watch: docker exec clab-dot1x-nac-supplicant-fail tail -f /var/log/wpa_supplicant.log"
