#!/bin/bash
# radius/setup.sh — configure FreeRADIUS and start it in debug mode

set -e

# Configure IP on eth1 (link to authenticator)
ip link set eth1 up
ip addr add 192.168.100.2/24 dev eth1 2>/dev/null || true

# Fix cert permissions — FreeRADIUS runs as freerad user
chown freerad:freerad \
    /etc/freeradius/3.0/certs/ca.pem \
    /etc/freeradius/3.0/certs/server.pem \
    /etc/freeradius/3.0/certs/server.key \
    /etc/freeradius/3.0/certs/dh
chmod 640 /etc/freeradius/3.0/certs/server.key

# Enable required modules and sites (safe to re-run)
ln -sf /etc/freeradius/3.0/mods-available/eap \
       /etc/freeradius/3.0/mods-enabled/eap 2>/dev/null || true
ln -sf /etc/freeradius/3.0/mods-available/mschap \
       /etc/freeradius/3.0/mods-enabled/mschap 2>/dev/null || true
ln -sf /etc/freeradius/3.0/mods-available/files \
       /etc/freeradius/3.0/mods-enabled/files 2>/dev/null || true
ln -sf /etc/freeradius/3.0/sites-available/inner-tunnel \
       /etc/freeradius/3.0/sites-enabled/inner-tunnel 2>/dev/null || true

# Start FreeRADIUS in debug mode, log to file for inspection
mkdir -p /var/log/freeradius
nohup freeradius -X -f > /var/log/freeradius/debug.log 2>&1 &

echo "[radius] FreeRADIUS started in debug mode (PID $!)"
echo "[radius] View logs: docker exec clab-dot1x-nac-radius tail -f /var/log/freeradius/debug.log"
