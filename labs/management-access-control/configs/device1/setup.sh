#!/bin/bash
set -e

ip link set eth1 up
ip link set eth2 up
ip addr replace 192.168.99.1/24 dev eth1
ip addr replace 192.168.50.1/24 dev eth2

adduser -D neteng
echo 'neteng:labpass' | chpasswd
mkdir -p /run/sshd
cat > /etc/ssh/sshd_config << 'EOF'
Port 22
PasswordAuthentication yes
PermitRootLogin no
PidFile /run/sshd.pid
EOF
ssh-keygen -A
/usr/sbin/sshd

mkdir -p /srv/ui
echo management-access-control > /srv/ui/index.html
python3 -m http.server 8443 --directory /srv/ui >/tmp/http8443.log 2>&1 &

iptables -F INPUT
iptables -P INPUT ACCEPT

echo "[device1] SSH on 22 and UI on 8443 ready"
