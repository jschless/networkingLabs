#!/bin/bash
set -e

ip link set eth1 up
ip addr add 192.0.2.1/30 dev eth1

mkdir -p /var/lib/thehive
cat > /var/lib/thehive/case.json << 'EOF'
{
  "title": "SOC Lab DMZ Intrusion",
  "severity": 2,
  "observables": ["10.10.10.10", "172.16.10.10", "SOC_LAB_Test_File"],
  "status": "Open",
  "tasks": ["Triage Suricata alert", "Pivot to Zeek logs", "Review packet evidence", "Write timeline"]
}
EOF

echo "[case-mgmt] case artifact ready"
