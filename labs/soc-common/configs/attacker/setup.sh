#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.10.10.10/24 dev eth1
ip route replace default via 10.10.10.1

mkdir -p /opt/soc-lab
cat > /opt/soc-lab/run-attack-sequence.sh << 'EOF'
#!/bin/bash
set -e

curl -fsS http://172.16.10.10/ >/dev/null || true
curl -fsS http://172.16.10.10/downloads/readme.txt >/dev/null || true
nmap -Pn -p 22,80,443,8080 172.16.10.10 172.16.20.10 >/tmp/nmap-dmz.txt || true
for i in $(seq 1 4); do
  nc -z -w1 172.16.10.10 22 >/dev/null 2>&1 || true
done
EOF
chmod +x /opt/soc-lab/run-attack-sequence.sh

echo "[attacker] 10.10.10.10/24 ready"
