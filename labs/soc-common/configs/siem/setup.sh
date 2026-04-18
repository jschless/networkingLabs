#!/bin/bash
set -e

ip link set eth1 up
ip addr add 192.0.2.1/30 dev eth1

mkdir -p /var/lib/soc-siem
cat > /var/lib/soc-siem/indexes.json << 'EOF'
[
  {"index":"zeek-conn","documents":3,"status":"green"},
  {"index":"suricata-alerts","documents":2,"status":"green"},
  {"index":"yara-hits","documents":1,"status":"green"}
]
EOF
cat > /var/lib/soc-siem/hvt-dashboard.ndjson << 'EOF'
{"type":"dashboard","id":"soc-dmz-hvt","attributes":{"title":"SOC DMZ HVT Monitoring"}}
{"type":"visualization","id":"suricata-severity","attributes":{"title":"Suricata alert severity"}}
{"type":"visualization","id":"zeek-top-sources","attributes":{"title":"Zeek top source IPs"}}
{"type":"visualization","id":"yara-hits","attributes":{"title":"YARA file hits"}}
EOF

echo "[siem] lightweight SIEM artifact store ready"
