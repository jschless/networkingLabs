#!/bin/bash
set -e

ip link set eth1 up
ip addr add 192.0.2.1/30 dev eth1

mkdir -p /var/lib/misp /etc/suricata/rules
cat > /var/lib/misp/iocs.json << 'EOF'
[
  {"type":"ip-dst","value":"172.16.10.10","event":"SOC-LAB-DMZ-HVT"},
  {"type":"domain","value":"dmz-web.lab","event":"SOC-LAB-DMZ-HVT"}
]
EOF
cat > /etc/suricata/rules/misp-generated.rules << 'EOF'
alert ip any any -> 172.16.10.10 any (msg:"MISP IOC SOC-LAB-DMZ-HVT"; sid:990001; rev:1;)
EOF

echo "[misp] IOC store and Suricata export ready"
