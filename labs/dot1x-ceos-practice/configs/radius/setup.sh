#!/bin/bash

set -e

ip link set eth1 up
ip addr add 192.168.100.2/24 dev eth1 2>/dev/null || true

install -d -m 755 /etc/freeradius/3.0/certs/lab
cp /lab-certs/ca.pem /etc/freeradius/3.0/certs/lab/ca.pem
cp /lab-certs/server.pem /etc/freeradius/3.0/certs/lab/server.pem
cp /lab-certs/server.key /etc/freeradius/3.0/certs/lab/server.key
cp /lab-certs/dh /etc/freeradius/3.0/certs/lab/dh
chown freerad:freerad /etc/freeradius/3.0/certs/lab/*
chmod 640 /etc/freeradius/3.0/certs/lab/server.key

ln -sf /etc/freeradius/3.0/mods-available/eap \
       /etc/freeradius/3.0/mods-enabled/eap 2>/dev/null || true
ln -sf /etc/freeradius/3.0/mods-available/mschap \
       /etc/freeradius/3.0/mods-enabled/mschap 2>/dev/null || true
ln -sf /etc/freeradius/3.0/mods-available/files \
       /etc/freeradius/3.0/mods-enabled/files 2>/dev/null || true
ln -sf /etc/freeradius/3.0/sites-available/inner-tunnel \
       /etc/freeradius/3.0/sites-enabled/inner-tunnel 2>/dev/null || true

mkdir -p /var/log/freeradius
nohup freeradius -X -f > /var/log/freeradius/debug.log 2>&1 &

echo "[radius] FreeRADIUS started in debug mode (PID $!)"
