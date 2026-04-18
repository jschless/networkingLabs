#!/bin/bash
set -e

ip link set eth1 up
ip addr add 192.0.2.1/30 dev eth1

mkdir -p /var/lib/arkime
cat > /var/lib/arkime/sessions.json << 'EOF'
[
  {"id":"arkime-demo-1","src":"10.10.10.10","dst":"172.16.10.10","port":80,"protocol":"http","pcap":"/pcap/soc-lab-demo.pcap"},
  {"id":"arkime-demo-2","src":"10.10.10.10","dst":"172.16.20.10","port":8080,"protocol":"http","pcap":"/pcap/soc-lab-demo.pcap"}
]
EOF

echo "[arkime] local session index ready"
