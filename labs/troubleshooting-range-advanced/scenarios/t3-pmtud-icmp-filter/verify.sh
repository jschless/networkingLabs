#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
if docker exec "$P-edge1" iptables -C OUTPUT -p icmp --icmp-type fragmentation-needed -j DROP 2>/dev/null; then exit 1; fi
[[ "$(docker exec "$P-edge1" cat /sys/class/net/eth1/mtu)" == 1400 ]]
[[ "$(docker exec "$P-corp1" cat /sys/class/net/eth1/mtu)" == 1500 ]]
docker exec "$P-internet1" ip route flush cache || true
docker exec "$P-corp1" python3 -c 'import socket; s=socket.create_connection(("198.18.10.10",8080),3); s.sendall(b"GET /index.html HTTP/1.0\r\n\r\n"); assert len(s.recv(4096))>100'
docker exec "$P-corp1" python3 -c 'import socket; s=socket.create_connection(("198.18.10.10",8080),4); s.sendall(b"GET /large.bin HTTP/1.0\r\n\r\n"); d=b""; exec("while True:\n c=s.recv(8192)\n if not c: break\n d+=c"); assert len(d)>65000'
echo 'PASS: original MTUs remain and both controlled transfers complete.'
