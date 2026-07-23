#!/usr/bin/env bash
set -euo pipefail

ip link set eth1 up
ip addr add 192.168.99.2/24 dev eth1 2>/dev/null || true
install -d -o freerad -g freerad /etc/freeradius/3.0/certs
install -o freerad -g freerad -m 0644 /opt/lab-pki/golden/ca.pem /etc/freeradius/3.0/certs/ca.pem
install -o freerad -g freerad -m 0644 /opt/lab-pki/golden/server.pem /etc/freeradius/3.0/certs/server.pem
install -o freerad -g freerad -m 0640 /opt/lab-pki/golden/server.key /etc/freeradius/3.0/certs/server.key
install -o freerad -g freerad -m 0644 /opt/lab-pki/golden/dh /etc/freeradius/3.0/certs/dh
ln -sf /etc/freeradius/3.0/mods-available/eap /etc/freeradius/3.0/mods-enabled/eap
ln -sf /etc/freeradius/3.0/mods-available/files /etc/freeradius/3.0/mods-enabled/files
ln -sf /etc/freeradius/3.0/mods-available/mschap /etc/freeradius/3.0/mods-enabled/mschap
ln -sf /etc/freeradius/3.0/sites-available/inner-tunnel /etc/freeradius/3.0/sites-enabled/inner-tunnel
freeradius -XC
mkdir -p /var/log/freeradius
nohup freeradius -X -f > /var/log/freeradius/debug.log 2>&1 &
echo "radius started pid=$!"
