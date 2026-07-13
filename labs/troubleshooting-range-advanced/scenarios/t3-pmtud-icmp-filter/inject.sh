#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
docker exec "$P-edge1" iptables -I OUTPUT 1 -p icmp --icmp-type fragmentation-needed -j DROP
docker exec "$P-internet1" ip route flush cache || true
docker exec "$P-corp1" python3 -c 'import socket; s=socket.create_connection(("198.18.10.10",8080),2); s.sendall(b"GET /index.html HTTP/1.0\r\n\r\n"); assert len(s.recv(4096))>100'
if docker exec "$P-corp1" timeout 5 python3 -c 'import socket; s=socket.create_connection(("198.18.10.10",8080),2); s.sendall(b"GET /large.bin HTTP/1.0\r\n\r\n"); d=b""; exec("while True:\n c=s.recv(8192)\n if not c: break\n d+=c"); assert len(d)>65000' 2>/dev/null; then exit 1; fi
echo 'Ticket symptom is active.'
