#!/usr/bin/env bash
set -euo pipefail
ip link set eth1 up
ip addr add 10.130.0.10/24 dev eth1
install -d /etc/wpa_supplicant
cp /opt/lab-pki/golden/ca.pem /etc/wpa_supplicant/radius-ca.pem
cp /opt/lab-pki/golden/quarantine-user.pem /etc/wpa_supplicant/client.pem
cp /opt/lab-pki/golden/quarantine-user.key /etc/wpa_supplicant/client.key
cat >/etc/wpa_supplicant/quarantine.conf <<'EOF'
network={
  key_mgmt=IEEE8021X
  eap=TLS
  identity="quarantine-user"
  ca_cert="/etc/wpa_supplicant/radius-ca.pem"
  client_cert="/etc/wpa_supplicant/client.pem"
  private_key="/etc/wpa_supplicant/client.key"
  domain_suffix_match="radius.lab"
  eapol_flags=0
}
EOF
sleep 3
wpa_supplicant -D wired -i eth1 -c /etc/wpa_supplicant/quarantine.conf -B -P /run/wpa-quarantine.pid -f /var/log/wpa-quarantine.log
