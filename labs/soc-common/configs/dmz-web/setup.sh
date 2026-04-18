#!/bin/bash
set -e

ip link set eth1 up
ip addr add 172.16.10.10/24 dev eth1
ip route replace default via 172.16.10.1

mkdir -p /srv/www/downloads
cat > /srv/www/index.html << 'EOF'
dmz-web online
EOF
cat > /srv/www/downloads/readme.txt << 'EOF'
SOC_LAB_TEST_FILE harmless file transfer for Zeek and YARA exercises
EOF

python3 -m http.server 80 --directory /srv/www >/tmp/dmz-web-http.log 2>&1 &
/usr/sbin/sshd -D >/tmp/dmz-web-sshd.log 2>&1 &

echo "[dmz-web] HTTP on 172.16.10.10:80 and SSH on :22 ready"
